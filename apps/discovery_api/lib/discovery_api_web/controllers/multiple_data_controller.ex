defmodule DiscoveryApiWeb.MultipleDataController do
  use DiscoveryApiWeb, :controller
  require Logger
  alias DiscoveryApiWeb.MultipleDataView
  alias DiscoveryApiWeb.Utilities.AuthUtils

  @prestige_session_opts Application.get_env(:prestige, :session_opts)

  plug(:accepts, MultipleDataView.accepted_formats())

  def query(conn, _params) do
    current_user = conn.assigns.current_user

    with {:ok, statement, conn} <- read_body(conn),
         true <- AuthUtils.authorized_to_query?(statement, current_user),
         session <- Prestige.new_session(@prestige_session_opts) do
      format = get_format(conn)
      data_stream = Prestige.query!(session, statement) |> Prestige.Result.as_maps()

      rendered_data_stream = MultipleDataView.render_as_stream(:data, format, %{stream: data_stream})

      resp_as_stream(conn, rendered_data_stream, format)
    else
      _ ->
        render_error(conn, 400, "Bad Request")
    end
  rescue
    Prestige.BadRequestError -> render_error(conn, 400, "Bad Request")
    error in [Prestige.Error] -> render_error(conn, 400, error)
  end
end
