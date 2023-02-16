defmodule AndiWeb.API.IngestionController do
  @moduledoc """
  This module handles the creation and retrieval of ingestions in redis.
  """

  use AndiWeb, :controller

  require Logger
  import SmartCity.Event, only: [ingestion_update: 0]
  import AndiWeb.IngestionLiveView.EditIngestionLiveView, only: [publish_ingestion: 2]
  alias SmartCity.Ingestion
  alias Andi.Services.IngestionStore
  alias Andi.Services.DatasetStore
  alias Andi.InputSchemas.InputConverter

  access_levels(
    create: [:private],
    get: [:private],
    get_all: [:private],
    delete: [:private],
    publish: [:private]
  )

  @instance_name Andi.instance_name()

  @doc """
  Parse a data message and post the created ingestion to redis
  """

  @spec create(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def create(conn, _params) do
    # TODO: Merge create/publish endpoints into a single "Update" endpoint
    with {:ok, message} <- check_and_add_id(conn.body_params) |> IO.inspect(label: "ingestion1"),
         {:ok, parsed_message} <- trim_required_fields(message),
         :valid <- validate_changes(parsed_message),
         ingestion <- new_ingestion(parsed_message),
         :ok <- write_ingestion(ingestion) do
      respond(conn, :created, ingestion) |> IO.inspect(label: "ingestion response")
    else
      {:invalid, errors} ->
        respond(conn, :bad_request, %{errors: errors})

      error ->
        Logger.error("Failed to create ingestion: #{inspect(error)}")
        respond(conn, :internal_server_error, "Unable to process your request")
    end
  end

  def validate_changes(ingestion) do
    changeset = InputConverter.smrt_ingestion_to_full_changeset(ingestion)

    with true <- changeset.valid?,
         :ok <- validate_target_dataset(ingestion) do
      :valid
    else
      false -> {:invalid, format_changeset_errors(changeset)}
      {:error, error} -> {:invalid, error}
    end
  end

  defp validate_target_dataset(ingestion) do
    dataset_id = ingestion["targetDataset"]

    IO.inspect(dataset_id, label: "dataset_id")
    case dataset_exists?(dataset_id) do
      {:ok, true} -> :ok
      {:ok, false} -> {:error, "Target dataset does not exist"}
      {:error, _} -> {:error, "Unable to retrieve target dataset"}
    end
  end

  defp dataset_exists?(id) do
    case DatasetStore.get(id) |> IO.inspect(label: "dataset store") do
      {:ok, nil} -> {:ok, false}
      {:ok, dataset} -> {:ok, true}
      {:error, error} -> {:error, error}
    end
  end

  defp format_changeset_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} ->
      msg
    end)
  end

  @doc """
  Publish an already created ingestion
  """
  @spec publish(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def publish(conn, %{"id" => ingestion_id}) do
    with {:ok, _} <- publish_ingestion(ingestion_id, :api),
         {:ok, ingestion} <- IngestionStore.get(ingestion_id) do
      respond(conn, 200, ingestion)
    else
      {:not_found, nil} ->
        respond(conn, 404, "Ingestion not found")

      error ->
        Logger.error("Could not publish ingestion due to #{inspect(error)}")
        respond(conn, 500, "An error occcured when publishing the ingestion")
    end
  end

  @doc """
  Return all ingestions stored in redis
  """
  def get_all(conn, _params) do
    case IngestionStore.get_all() do
      {:ok, ingestions} ->
        respond(conn, :ok, ingestions)

      error ->
        Logger.error("Failed to retrieve ingestions: #{inspect(error)}")
        respond(conn, :not_found, "Unable to process your request")
    end
  end

  @doc """
  Returns an ingestion stored in redis
  """

  @spec get(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def get(conn, params) do
    case IngestionStore.get(Map.get(params, "ingestion_id")) do
      {:ok, nil} ->
        respond(conn, :not_found, "Ingestion not found")

      {:ok, ingestion} ->
        respond(conn, :ok, ingestion)

      error ->
        Logger.error("Failed to retrieve ingestion by id: #{inspect(error)}")
        respond(conn, :not_found, "Unable to process your request")
    end
  end

  defp write_ingestion(ingestion) do
    Andi.Schemas.AuditEvents.log_audit_event(:api, ingestion_update(), ingestion)
    Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)
  end

  @doc """
  Delete an ingestion
  """

  @spec delete(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def delete(conn, %{"id" => ingestion_id}) do
    case Andi.Services.IngestionDelete.delete(ingestion_id) do
      {:ok, ingestion} ->
        respond(conn, 200, ingestion)

      {:not_found, _} ->
        respond(conn, 404, "Ingestion not found")

      error ->
        Logger.error("Could not delete ingestion due to #{inspect(error)}")
        respond(conn, 500, "An error occcured when deleting the ingestion")
    end
  end

  defp respond(conn, status, body) do
    conn
    |> put_status(status)
    |> json(body)
  end

  defp check_and_add_id(message) do
    cond do
      Map.has_key?(message, "id") == false -> {:ok, Map.merge(message, %{"id" => UUID.uuid4()})}
      Map.get(message, "id") == nil -> {:ok, Map.merge(message, %{"id" => UUID.uuid4()})}
      ingestion_exists?(Map.get(message, "id")) == false -> {:invalid, "Do not include id in create call"}
      true -> {:ok, message}
    end
  end

  defp ingestion_exists?(id) do
    case IngestionStore.get(id) do
      {:ok, nil} -> false
      _ -> true
    end
  end

  defp trim_required_fields(%{"id" => _, "schema" => _, "extractSteps" => _} = map) do
    {:ok, trim_map(map)}
  end

  defp trim_required_fields(msg), do: {:error, "Cannot parse message: #{inspect(msg)}"}

  defp trim_list(data) do
    Enum.map(data, fn
      item when is_binary(item) -> String.trim(item)
      item when is_map(item) -> trim_map(item)
      item -> item
    end)
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

  defp new_ingestion(message) do
    message
    |> Ingestion.new()
  end
end
