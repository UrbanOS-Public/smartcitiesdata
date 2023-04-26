defmodule AndiWeb.API.AuditLogController do
  @moduledoc """
  Module returns audit logs from postgres.
  """
  use AndiWeb, :controller
  alias Andi.Schemas.AuditEvents

  access_levels(get: [:private])

  @spec get(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def get(conn, params) do
    audit_events =
      case Map.keys(params) do
        ["user_id"] -> AuditEvents.get_all_for_user(params["user_id"])
        ["audit_id"] -> AuditEvents.get(params["audit_id"])
        ["type"] -> AuditEvents.get_all_of_type(params["type"])
        ["event_id"] -> AuditEvents.get_all_by_event_id(params["event_id"])
        [] -> AuditEvents.get_all()
      end

    response =
      for event <- audit_events do
        trimmed_event =
          Map.from_struct(event)
          |> Map.delete(:__meta__)
          |> Kernel.inspect()

        "#{trimmed_event}\n"
      end

    text(conn, response)
  end
end
