defmodule AndiWeb.API.AuditLogController do
  @moduledoc """
  Module returns audit logs from postgres.
  """
  use AndiWeb, :controller
  alias Andi.Schemas.AuditEvents

  access_levels(get: [:private])

  @spec get(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def get(conn, params) do
    with {:ok, audit_events} <- get_audit_events(params) do
      text(conn, format_events(audit_events))
    else
      _ -> respond_error(conn)
    end
  end

  defp get_audit_events(params) do
    case Map.keys(params) do
      ["user_id"] -> {:ok, AuditEvents.get_all_for_user(params["user_id"])}
      ["audit_id"] -> {:ok, AuditEvents.get(params["audit_id"])}
      ["type"] -> {:ok, AuditEvents.get_all_of_type(params["type"])}
      ["event_id"] -> {:ok, AuditEvents.get_all_by_event_id(params["event_id"])}
      [] -> {:ok, AuditEvents.get_all()}
      _ -> {:error}
    end
  end

  defp format_events(audit_events) do
    for event <- audit_events do
      trimmed_event =
        Map.from_struct(event)
        |> Map.delete(:__meta__)
        |> Kernel.inspect()

      "#{trimmed_event}\n"
    end
  end

  defp respond_error(conn) do
    conn
    |> put_status(:bad_request)
    |> text(
      "Unsupported request. Only one filter can be used at a time - 'user_id', 'audit_id', 'type', 'event_id.'" <>
        "For time, exactly 'start' and 'end' must be used."
    )
  end
end
