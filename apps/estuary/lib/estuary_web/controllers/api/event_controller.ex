defmodule EstuaryWeb.API.EventController do
  @moduledoc """
  This module handles the retrival of events
  """
  use EstuaryWeb, :controller

  require Logger
  alias Estuary.Services.EventRetrievalService

  @doc """
  Return all events stored in presto
  """
  def get_all(conn, _params) do
    case EventRetrievalService.get_all() do
      events ->
        respond(conn, 200, events)

      error ->
        Logger.error("Failed to retrieve events: #{inspect(error)}")
        respond(conn, :not_found, "Unable to process your request")
    end
  end

  defp respond(conn, status, body) do
    conn
    |> put_status(status)
    |> json(body)
  end
end
