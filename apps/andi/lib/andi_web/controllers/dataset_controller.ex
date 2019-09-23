defmodule AndiWeb.DatasetController do
  @moduledoc """
  This module handles the creation and retrieval of datasets in redis.
  """

  use AndiWeb, :controller

  require Logger
  alias SmartCity.Registry.Dataset, as: RegDataset
  alias SmartCity.Dataset
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
         :valid <- is_valid(dataset),
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
  @spec get_all(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def get_all(conn, _params) do
    case Brook.get_all_values(:dataset) do
      {:ok, datasets} ->
        respond(conn, :ok, datasets)

      {_, error} ->
        Logger.error("Failed to retrieve datasets: #{inspect(error)}")
        respond(conn, :not_found, "Unable to process your request")
    end
  end

  defp write_dataset(dataset), do: Brook.Event.send(dataset_update(), :andi, dataset)

  # Deprecated function for backwards compatibility with SmartCity.Registry apps
  def write_old_dataset(dataset), do: RegDataset.write(dataset)

  @doc """
  Disable a dataset
  """
  @spec disable(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def disable(conn, params) do
    dataset_id = Map.get(params, "id")

    case Andi.Services.DatasetDisableService.disable(dataset_id) do
      {:ok, dataset} ->
        respond(conn, 200, dataset)

      {:not_found, _} ->
        respond(conn, 404, "Dataset not found")

      error ->
        Logger.error("Could not disable dataset due to #{inspect(error)}")
        respond(conn, 500, "An error occurred when disabling dataset")
    end
  end

  defp parse_message(%{"technical" => technical} = msg) do
    with org_name when not is_nil(org_name) <- Map.get(technical, "orgName"),
         data_name when not is_nil(data_name) <- Map.get(technical, "dataName"),
         system_name <- "#{org_name}__#{data_name}" do
      {:ok, put_in(msg, ["technical", "systemName"], system_name)}
    else
      _ -> {:error, "Cannot parse message: #{inspect(msg)}"}
    end
  end

  defp parse_message(msg), do: {:error, "Cannot parse message: #{inspect(msg)}"}

  defp is_valid(dataset) do
    found_match =
      Brook.get_all_values!(:dataset)
      |> Enum.any?(fn existing_dataset ->
        dataset.id != existing_dataset.id &&
          dataset.technical.systemName == existing_dataset.technical.systemName
      end)

    case found_match do
      true -> {:invalid, "Existing dataset has the same orgName and dataName"}
      false -> :valid
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
end
