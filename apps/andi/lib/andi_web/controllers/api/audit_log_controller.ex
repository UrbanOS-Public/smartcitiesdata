defmodule AndiWeb.API.AuditLogController do
  @moduledoc """
  Module returns audit logs from postgres.
  """
  use AndiWeb, :controller
  alias Andi.Schemas.AuditEvents

  access_levels(get: [:private])

  @generic_error_text "Unsupported request. Only one filter can be used at a time - 'user_id', 'audit_id', 'type', 'event_id.'" <>
                        "For time, exactly 'start_date' and 'end_date' must be used and formatted in ISO-8601. ex. /start_date=2020-12-31&end-date=2021-01-01"

  @spec get(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def get(conn, params) do
    with {:ok, audit_events} <- get_audit_events(params) do
      text(conn, format_events(audit_events))
    else
      {:error, error} -> respond_error(conn, error)
    end
  end

  defp get_audit_events(params) do
    case Map.keys(params) do
      ["user_id"] -> {:ok, AuditEvents.get_all_for_user(params["user_id"])}
      ["audit_id"] -> {:ok, AuditEvents.get(params["audit_id"])}
      ["type"] -> {:ok, AuditEvents.get_all_of_type(params["type"])}
      ["event_id"] -> {:ok, AuditEvents.get_all_by_event_id(params["event_id"])}
      ["start_date", "end_date"] -> get_range(params["start_date"], params["end_date"])
      ["end_date", "start_date"] -> get_range(params["start_date"], params["end_date"])
      [] -> {:ok, AuditEvents.get_all()}
      _ -> {:error, @generic_error_text}
    end
  end

  defp get_range(start_date, end_date) do
    with {:ok, start_struct} <- Date.from_iso8601(start_date),
         {:ok, end_struct} <- Date.from_iso8601(end_date) do
      {:ok, AuditEvents.get_all_in_range(start_struct, end_struct)}
    else
      {:error, _error} -> {:error, "Inproperly formatted dates. Use ISO-8601, ex. 2021-01-01"}
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

  defp respond_error(conn, error) do
    conn
    |> put_status(:bad_request)
    |> text(error)
  end
end
