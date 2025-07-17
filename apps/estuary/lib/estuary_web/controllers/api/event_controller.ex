defmodule EstuaryWeb.API.EventController do
  @moduledoc """
  This module handles the retrival of events
  """
  use EstuaryWeb, :controller

  require Logger
  alias Estuary.Services.EventRetrievalService
  alias Plug.Conn

  @doc """
  Return all events stored in presto
  """
  def get_all(conn, _params) do
    case event_retrieval_service().get_all() do
      {:ok, events} ->
        resp_as_stream(conn, 200, events)

      {:error, error} ->
        Logger.error("Failed to retrieve events: #{inspect(error)}")
        respond(conn, :not_found, "Unable to process your request")
    end
  end

  defp respond(conn, status, body) do
    conn
    |> put_status(status)
    |> json(body)
  end

  defp resp_as_stream(conn, status, stream) do
    conn = Conn.send_chunked(conn, status)

    stream
    |> data_as_json_string()
    |> data_as_stream()
    |> response(conn)
  end

  defp data_as_json_string(stream) do
    stream
    |> Stream.map(&Jason.encode!/1)
    |> Stream.intersperse(",")
  end

  defp data_as_stream(json_string) do
    [["["], json_string, ["]"]]
    |> Stream.concat()
  end

  defp response(events, conn) do
    events
    |> Enum.reduce_while(conn, fn event, conn ->
      case Conn.chunk(conn, event) do
        {:ok, conn} -> {:cont, conn}
        {:error, :closed} -> {:halt, conn}
      end
    end)
  end

  defp event_retrieval_service,
    do: Application.get_env(:estuary, :event_retrieval_service, EventRetrievalService)
end
