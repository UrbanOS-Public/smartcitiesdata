defmodule AndiWeb.EditController do
  use AndiWeb, :controller
  alias Andi.InputSchemas.Datasets

  def show(conn, %{"id" => id}) do
    case Datasets.get(id) do
      nil ->
        conn
        |> put_view(AndiWeb.ErrorView)
        |> put_status(404)
        |> render("404.html")

      dataset ->
        live_render(conn, AndiWeb.EditLiveView, session: %{"dataset" => dataset})
    end
  end
end
