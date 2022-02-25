defmodule AndiWeb.API.IngestionController do
  @moduledoc """
  This module handles the creation and retrieval of ingestions in redis.
  """

  use AndiWeb, :controller

  require Logger
  import SmartCity.Event, only: [ingestion_update: 0]

  alias SmartCity.Ingestion
  alias Andi.Services.IngestionStore
  alias Andi.InputSchemas.InputConverter

  access_levels(
    create: [:private],
    get: [:private],
    get_all: [:private],
    disable: [:private],
    delete: [:private]
  )

  @instance_name Andi.instance_name()

  @doc """
  Parse a data message and post the created ingestion to redis
  """

  @spec create(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def create(conn, _params) do
    with message <- add_uuid(conn.body_params),
         {:ok, parsed_message} <- trim_required_fields(message),
         :valid <- validate_changes(parsed_message),
         ingestion <- new_ingestion(parsed_message),
         :ok <- write_ingestion(ingestion) do
      respond(conn, :created, ingestion)
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

  defp write_ingestion(ingestion), do: Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

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
        Logger.error("Could not delete ignestion due to #{inspect(error)}")
        respond(conn, 500, "An error occcured when deleting the ingestion")
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

  defp trim_required_fields(%{"id" => id, "schema" => schema, "extractSteps" => extract_steps} = map) do
    {:ok,
     %{
       map
       | "id" => String.trim(id),
         "extractSteps" => trim_list(extract_steps),
         "schema" => trim_list(schema)
     }}
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
      field -> field
    end)
    |> Enum.into(Map.new())
  end

  defp new_ingestion(message) do
    message
    |> Ingestion.new()
  end
end
