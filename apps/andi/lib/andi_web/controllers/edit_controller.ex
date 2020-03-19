defmodule AndiWeb.EditController do
  use AndiWeb, :controller
  alias Andi.DatasetCache

  def show(conn, %{"id" => id}) do
    case DatasetCache.get(id) do
      %{"dataset" => dataset} ->
        live_render(conn, AndiWeb.EditLiveView, session: %{"dataset" => dataset})

      _ ->
        conn
        |> put_view(AndiWeb.ErrorView)
        |> put_status(404)
        |> render("404.html")
    end
  end
end
