defmodule AndiWeb.EditController do
  use AndiWeb, :controller
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Organizations

  def show_dataset(conn, %{"id" => id}) do
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

  def show_organization(conn, %{"id" => id}) do
    case Organizations.get(id) do
      nil ->
        conn
        |> put_view(AndiWeb.ErrorView)
        |> put_status(404)
        |> render("404.html")

      org ->
        live_render(conn, AndiWeb.EditOrganizationLiveView, session: %{"organization" => org})
    end
  end
end
