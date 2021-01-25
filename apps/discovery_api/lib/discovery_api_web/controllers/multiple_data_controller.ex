defmodule DiscoveryApiWeb.MultipleDataController do
  use DiscoveryApiWeb, :controller
  require Logger
  alias DiscoveryApiWeb.MultipleDataView
  alias DiscoveryApiWeb.Utilities.QueryAccessUtils
  import DiscoveryApiWeb.Utilities.StreamUtils

  import SmartCity.Event,
    only: [dataset_query: 0]

  plug(:accepts, MultipleDataView.accepted_formats())

  def query(conn, _params) do
    with {:ok, statement, conn} <- read_body(conn),
         {:ok, affected_models} <- QueryAccessUtils.get_affected_models(statement),
         {:ok, session} <- QueryAccessUtils.authorized_session(conn, affected_models) do
      Enum.each(affected_models, fn model ->
        Brook.Event.send(DiscoveryApi.instance_name(), dataset_query(), __MODULE__, model.id)
      end)

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
