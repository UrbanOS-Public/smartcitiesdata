defmodule AndiWeb.EditController do
  use AndiWeb, :controller
  alias Andi.DatasetCache

  def show(conn, %{"id" => id}) do
    with %{"dataset" => dataset} <- DatasetCache.get(id) do
      live_render(conn, AndiWeb.EditLiveView, session: %{dataset: dataset})
    else
      _ ->
        conn
        |> put_view(AndiWeb.ErrorView)
        |> put_status(404)
        |> render("404.html")
    end
  end
end
