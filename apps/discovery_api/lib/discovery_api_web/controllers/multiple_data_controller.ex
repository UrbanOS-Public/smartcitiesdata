defmodule DiscoveryApiWeb.MultipleDataController do
  use DiscoveryApiWeb, :controller
  require Logger
  alias DiscoveryApiWeb.MultipleDataView
  alias DiscoveryApiWeb.Utilities.QueryAccessUtils

  plug(:accepts, MultipleDataView.accepted_formats())

  def query(conn, _params) do
    current_user = conn.assigns.current_user

    with {:ok, statement, conn} <- read_body(conn),
         true <- QueryAccessUtils.authorized_to_query?(statement, current_user),
         session_opts <- DiscoveryApi.prestige_opts(),
         session <- Prestige.new_session(session_opts) do
      format = get_format(conn)

      data_stream =
        Prestige.stream!(session, statement)
        |> Stream.flat_map(&Prestige.Result.as_maps/1)

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
