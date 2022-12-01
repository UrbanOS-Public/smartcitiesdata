defmodule DiscoveryApiWeb.ApiKeyController do
  use DiscoveryApiWeb, :controller

  use Properties, otp_app: :discovery_api

  plug(:accepts, ["json"])
  getter(:raptor_url, generic: true)

  def regenerate_api_key(conn, params) do
    IO.inspect(params, label: "Params")
    current_user = conn.assigns.current_user.subject_id
    IO.inspect(current_user, label: "Current User")
    case RaptorService.regenerate_api_key_for_user(raptor_url(), current_user) do
      {:error, error} -> render_error(conn, 404, "Not Found")
      {:ok, result} -> render(conn, :fetch_organization, org: result)
    end
  end

#  def regenerate_api_key(conn, params) do
#    IO.inspect(payload, label: "Payload")
#    render_error(conn, 404, "Not Found")
#  end
end
