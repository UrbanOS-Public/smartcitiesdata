defmodule AndiWeb.EditController do
  use AndiWeb, :controller
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Organizations

  def show_dataset(conn, %{"id" => id}) do
    %{"roles" => roles, "user_id" => user_id} = AndiWeb.Auth.TokenHandler.Plug.current_resource(conn)

    is_curator = "Curator" in roles

    case get_dataset_if_accessible(id, is_curator, user_id) do
      nil ->
        conn
        |> put_view(AndiWeb.ErrorView)
        |> put_status(404)
        |> render("404.html")

      dataset ->
        live_render(conn, AndiWeb.EditLiveView, session: %{"dataset" => dataset})
    end
  end

  defp get_dataset_if_accessible(_id, _is_curator, nil), do: nil

  defp get_dataset_if_accessible(id, true, _user_id) do
    Datasets.get(id)
  end

  defp get_dataset_if_accessible(id, false, user_id) do
    case Datasets.get(id) do
      nil -> nil
      %{owner_id: owner_id} = dataset when owner_id == user_id -> dataset
      _dataset -> nil
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
