defmodule AndiWeb.EditController do
  use AndiWeb, :controller
  use Properties, otp_app: :andi
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Organizations
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.AccessGroups
  alias Andi.Schemas.DatasetDownload
  alias Andi.Schemas.User

  getter(:hosted_bucket, generic: true)

  @bucket_path "samples/"

  access_levels(
    edit_organization: [:private],
    edit_ingestion: [:private],
    edit_user: [:private],
    edit_dataset: [:private],
    edit_submission: [:private, :public],
    download_dataset_sample: [:private],
    edit_access_group: [:private]
  )

  def edit_dataset(conn, %{"id" => id}) do
    render_view_if_accessible(conn, id, AndiWeb.EditLiveView)
  end

  def edit_submission(conn, %{"id" => id}) do
    render_view_if_accessible(conn, id, AndiWeb.SubmitLiveView)
  end

  def download_dataset_sample(conn, %{"id" => dataset_id}) do
    %{"user_id" => current_user_id, "is_curator" => is_curator} = AndiWeb.Auth.TokenHandler.Plug.current_resource(conn)

    andi_dataset = Andi.InputSchemas.Datasets.get(dataset_id)
    dataset_link = andi_dataset.datasetLink
    request_headers = conn.req_headers |> Enum.map(&Tuple.to_list/1) |> Jason.encode!()

    with true <- is_curator,
         false <- is_nil(dataset_link) do
      persist_dataset_download_request(dataset_id, dataset_link, current_user_id, request_headers, true)
      {:ok, presigned_url} = presigned_url(dataset_id, dataset_link)

      redirect(conn, external: presigned_url)
    else
      _ ->
        persist_dataset_download_request(dataset_id, dataset_link, current_user_id, request_headers, false)

        conn
        |> put_view(AndiWeb.ErrorView)
        |> put_status(404)
        |> render("404.html")
    end
  end

  defp persist_dataset_download_request(dataset_id, dataset_link, current_user_id, req_headers, download_success) do
    download_request = %{
      dataset_id: dataset_id,
      dataset_link: dataset_link,
      request_headers: req_headers,
      timestamp: DateTime.utc_now(),
      user_accessing: current_user_id,
      download_success: download_success
    }

    download_request_changeset = DatasetDownload.changeset(%DatasetDownload{}, download_request)
    Andi.Repo.insert_or_update(download_request_changeset)
  end

  defp presigned_url(dataset_id, dataset_link) do
    file_name = get_file_name_from_dataset_link(dataset_link)

    ExAws.Config.new(:s3)
    |> ExAws.S3.presigned_url(:get, "#{hosted_bucket()}/#{@bucket_path}#{dataset_id}", file_name)
    |> case do
      {:ok, presigned_url} -> {:ok, presigned_url}
      {_, error} -> {:error, error}
    end
  end

  defp get_file_name_from_dataset_link(dataset_link) do
    dataset_link
    |> String.split("/")
    |> List.last()
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
        live_render(conn, view, session: %{"dataset" => dataset, "is_curator" => is_curator, "user_id" => user_id})
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
    %{"is_curator" => is_curator, "user_id" => user_id} = AndiWeb.Auth.TokenHandler.Plug.current_resource(conn)

    case Organizations.get(id) do
      nil ->
        conn
        |> put_view(AndiWeb.ErrorView)
        |> put_status(404)
        |> render("404.html")

      org ->
        live_render(conn, AndiWeb.EditOrganizationLiveView,
          session: %{"organization" => org, "is_curator" => is_curator, "user_id" => user_id}
        )
    end
  end

  def edit_ingestion(conn, %{"id" => id}) do
    %{"is_curator" => is_curator, "user_id" => user_id} = AndiWeb.Auth.TokenHandler.Plug.current_resource(conn)

    case Ingestions.get(id) do
      nil ->
        conn
        |> put_view(AndiWeb.ErrorView)
        |> put_status(404)
        |> render("404.html")

      ingestion ->
        live_render(conn, AndiWeb.IngestionLiveView.EditIngestionLiveView,
          session: %{"ingestion" => ingestion, "is_curator" => is_curator, "user_id" => user_id}
        )
    end
  end

  def edit_access_group(conn, %{"id" => id}) do
    %{"is_curator" => is_curator} = AndiWeb.Auth.TokenHandler.Plug.current_resource(conn)

    case AccessGroups.get(id) do
      nil ->
        conn
        |> put_view(AndiWeb.ErrorView)
        |> put_status(404)
        |> render("404.html")

      access_group ->
        live_render(conn, AndiWeb.AccessGroupLiveView.EditAccessGroupLiveView,
          session: %{"access_group" => access_group, "is_curator" => is_curator}
        )
    end
  end

  def edit_user(conn, %{"id" => id}) do
    %{"is_curator" => is_curator, "user_id" => user_id} = AndiWeb.Auth.TokenHandler.Plug.current_resource(conn)

    case User.get_by_id(id) do
      nil ->
        conn
        |> put_view(AndiWeb.ErrorView)
        |> put_status(404)
        |> render("404.html")

      user ->
        live_render(conn, AndiWeb.UserLiveView.EditUserLiveView,
          session: %{"is_curator" => is_curator, "user" => user, "user_id" => user_id}
        )
    end
  end
end
