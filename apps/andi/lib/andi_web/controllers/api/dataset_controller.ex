defmodule AndiWeb.API.DatasetController do
  @moduledoc """
  This module handles the creation and retrieval of datasets in redis.
  """

  use AndiWeb, :controller

  require Logger
  alias SmartCity.Dataset
  alias Andi.Services.DatasetStore
  import SmartCity.Event, only: [dataset_update: 0]
  alias Andi.InputSchemas.InputConverter

  @instance_name Andi.instance_name()

  @doc """
  Parse a data message and post the created dataset to redis
  """
  @spec create(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def create(conn, _params) do
    with message <- add_uuid(conn.body_params),
         {:ok, parsed_message} <- trim_fields(message),
         :valid <- validate_changes(parsed_message),
         {:ok, dataset} <- new_dataset(parsed_message),
         :ok <- write_dataset(dataset) do
      respond(conn, :created, dataset)
    else
      {:invalid, errors} ->
        respond(conn, :bad_request, %{errors: errors})

      error ->
        Logger.error("Failed to create dataset: #{inspect(error)}")
        respond(conn, :internal_server_error, "Unable to process your request")
    end
  end

  def validate_changes(dataset) do
    changeset = InputConverter.smrt_dataset_to_full_changeset(dataset)

    if changeset.valid? do
      :valid
    else
      {:invalid, format_changeset_errors(changeset)}
    end
  end

  defp format_changeset_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} ->
      msg
    end)
  end

  @doc """
  Return all datasets stored in redis
  """
  def get_all(conn, _params) do
    case DatasetStore.get_all() do
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
  @spec get(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def get(conn, params) do
    case DatasetStore.get(Map.get(params, "dataset_id")) do
      {:ok, nil} -> respond(conn, :not_found, "Dataset not found")
      {:ok, dataset} -> respond(conn, :ok, dataset)
    end
  end

  defp write_dataset(dataset), do: Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)

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

  defp trim_fields(%{"id" => id, "technical" => technical, "business" => business} = map) do
    {:ok,
     %{
       map
       | "id" => String.trim(id),
         "technical" => trim_map(technical),
         "business" => trim_map(business)
     }}
  end

  defp trim_fields(msg), do: {:error, "Cannot parse message: #{inspect(msg)}"}

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

  defp new_dataset(message) do
    message
    |> with_system_name()
    |> Dataset.new()
  end

  defp with_system_name(%{"technical" => technical} = msg) do
    system_name = "#{technical["orgName"]}__#{technical["dataName"]}"
    put_in(msg, ["technical", "systemName"], system_name)
  end
end
