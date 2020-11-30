defmodule AndiWeb.EditController do
  use AndiWeb, :controller
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Organizations

  access_levels(
    edit_organization: [:private],
    edit_dataset: [:private],
    edit_submission: [:private, :public]
  )

  def edit_dataset(conn, %{"id" => id}) do
    render_view_if_accessible(conn, id, AndiWeb.EditLiveView)
  end

  def edit_submission(conn, %{"id" => id}) do
    render_view_if_accessible(conn, id, AndiWeb.SubmitLiveView)
  end

  defp render_view_if_accessible(conn, id, view) do
    %{"user_id" => user_id, "is_curator" => is_curator} = AndiWeb.Auth.TokenHandler.Plug.current_resource(conn)

    case get_dataset_if_accessible(id, is_curator, user_id) do
      nil ->
        conn
        |> put_view(AndiWeb.ErrorView)
        |> put_status(404)
        |> render("404.html")

      dataset ->
        live_render(conn, view, session: %{"dataset" => dataset, "is_curator" => is_curator})
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

  def edit_organization(conn, %{"id" => id}) do
    %{"is_curator" => is_curator} = AndiWeb.Auth.TokenHandler.Plug.current_resource(conn)

    case Organizations.get(id) do
      nil ->
        conn
        |> put_view(AndiWeb.ErrorView)
        |> put_status(404)
        |> render("404.html")

      org ->
        live_render(conn, AndiWeb.EditOrganizationLiveView, session: %{"organization" => org, "is_curator" => is_curator})
    end
  end

  def access_level(conn) do
    %{"is_curator" => is_curator?} = AndiWeb.Auth.TokenHandler.Plug.current_resource(conn)

    if is_curator? do
      [:private]
    else
      [:private, :public]
    end
  end
end
