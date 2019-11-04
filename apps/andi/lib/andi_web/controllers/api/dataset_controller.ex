defmodule AndiWeb.DatasetController do
  @moduledoc """
  This module handles the creation and retrieval of datasets in redis.
  """

  use AndiWeb, :controller

  alias AndiWeb.DatasetValidator

  require Logger
  alias SmartCity.Registry.Dataset, as: RegDataset
  alias SmartCity.Dataset
  alias Andi.Services.DatasetRetrieval
  import Andi
  import SmartCity.Event, only: [dataset_update: 0]

  @doc """
  Parse a data message and post the created dataset to redis
  """
  @spec create(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def create(conn, _params) do
    with message <- add_uuid(conn.body_params),
         {:ok, parsed_message} <- parse_message(message),
         {:ok, old_dataset} <- RegDataset.new(parsed_message),
         {:ok, dataset} <- Dataset.new(parsed_message),
         :valid <- DatasetValidator.validate(dataset),
         {:ok, _id} <- write_old_dataset(old_dataset),
         :ok <- write_dataset(dataset) do
      respond(conn, :created, dataset)
    else
      {:invalid, reason} ->
        respond(conn, :bad_request, %{reason: reason})

      error ->
        Logger.error("Failed to create dataset: #{inspect(error)}")
        respond(conn, :internal_server_error, "Unable to process your request")
    end
  end

  @doc """
  Return all datasets stored in redis
  """
  def get_all(conn, _params) do
    case DatasetRetrieval.get_all() do
      {:ok, datasets} ->
        respond(conn, :ok, datasets)

      error ->
        Logger.error("Failed to retrieve datasets: #{inspect(error)}")
        respond(conn, :not_found, "Unable to process your request")
    end
  end

  @doc """
  Returns a dataset stored in redis
  """
  @spec get_all(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def get(conn, params) do
    case Brook.get(instance_name(), :dataset, Map.get(params, "dataset_id")) do
      {:ok, nil} -> respond(conn, :not_found, "Dataset not found")
      {:ok, dataset} -> respond(conn, :ok, dataset)
    end
  end

  defp write_dataset(dataset), do: Brook.Event.send(instance_name(), dataset_update(), :andi, dataset)

  # Deprecated function for backwards compatibility with SmartCity.Registry apps
  def write_old_dataset(dataset), do: RegDataset.write(dataset)

  @doc """
  Disable a dataset
  """
  @spec disable(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def disable(conn, params) do
    dataset_id = Map.get(params, "id")

    case Andi.Services.DatasetDisable.disable(dataset_id) do
      {:ok, dataset} ->
        respond(conn, 200, dataset)

      {:not_found, _} ->
        respond(conn, 404, "Dataset not found")

      error ->
        Logger.error("Could not disable dataset due to #{inspect(error)}")
        respond(conn, 500, "An error occurred when disabling dataset")
    end
  end

  @doc """
  Delete a dataset
  """
  @spec delete(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def delete(conn, %{"id" => dataset_id}) do
    case Andi.Services.DatasetDelete.delete(dataset_id) do
      {:ok, dataset} ->
        respond(conn, 200, dataset)

      {:not_found, _} ->
        respond(conn, 404, "Dataset not found")

      error ->
        Logger.error("Could not delete dataset due to #{inspect(error)}")
        respond(conn, 500, "An error occcured when deleting dataset")
    end
  end

  defp respond(conn, status, body) do
    conn
    |> put_status(status)
    |> json(body)
  end

  defp add_uuid(message) do
    uuid = UUID.uuid4()

    Map.merge(message, %{"id" => uuid}, fn _k, v1, _v2 -> v1 end)
  end

  defp parse_message(%{"technical" => _technical} = msg) do
    msg
    |> trim_fields()
    |> downcase_schema()
    |> create_system_name()
  end

  defp parse_message(msg), do: {:error, "Cannot parse message: #{inspect(msg)}"}

  defp trim_fields(%{"id" => id, "technical" => technical, "business" => business} = map) do
    %{
      map
      | "id" => String.trim(id),
        "technical" => trim_map(technical),
        "business" => trim_map(business)
    }
  end

  defp trim_map(data) do
    data
    |> Enum.map(fn
      {key, val} when is_binary(val) -> {key, String.trim(val)}
      {key, val} when is_list(val) -> {key, trim_list(val)}
      field -> field
    end)
    |> Enum.into(Map.new())
  end

  defp trim_list(data) do
    Enum.map(data, fn
      item when is_binary(item) -> String.trim(item)
      item -> item
    end)
  end

  defp downcase_schema(%{"technical" => technical} = msg) do
    downcased_schema =
      technical
      |> Map.get("schema")
      |> Andi.SchemaDowncaser.downcase_schema()

    put_in(msg, ["technical", "schema"], downcased_schema)
  end

  defp create_system_name(%{"technical" => technical} = msg) do
    with org_name when not is_nil(org_name) <- Map.get(technical, "orgName"),
         data_name when not is_nil(data_name) <- Map.get(technical, "dataName"),
         system_name <- "#{org_name}__#{data_name}" do
      {:ok, put_in(msg, ["technical", "systemName"], system_name)}
    else
      _ -> {:error, "Cannot parse message: #{inspect(msg)}"}
    end
  end
end
