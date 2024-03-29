defmodule AndiWeb.ReportsController do
  use AndiWeb, :controller
  import Ecto.Query, only: [from: 2]
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Organization

  access_levels(download_report: [:private])

  def download_report(conn, _params) do
    csv = CSV.encode(build_csv()) |> Enum.to_list() |> to_string()

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"record.csv\"")
    |> resp(200, csv)
  end

  defp build_csv() do
    values =
      get_datasets()
      |> Enum.map(fn dataset ->
        [
          dataset.id,
          dataset.dataTitle,
          dataset.orgTitle,
          dataset.systemName,
          get_users_for_dataset(dataset.is_public, dataset.access_groups, dataset.org_id),
          get_keyword_list(dataset.keywords),
          get_access_level(dataset.is_public)
        ]
      end)

    [["Dataset ID", "Dataset Title", "Organization", "System Name", "Users", "Tags", "Access Level"] | values]
  end

  defp get_users_for_dataset(is_public, access_groups, org_id) do
    if is_public do
      "All (public)"
    else
      [get_users_in_org(org_id), get_users_in_access_groups(access_groups)]
      |> Enum.concat()
      |> Enum.dedup()
      |> Enum.sort()
      |> Enum.join(", ")
    end
  end

  defp get_access_level(is_public) do
    if is_public do
      "Public"
    else
      "Private"
    end
  end

  defp get_keyword_list(keywords) do
    if length(keywords) > 0 do
      Enum.join(keywords, ", ")
    else
      []
    end
  end

  defp get_datasets() do
    query =
      from(dataset in Dataset,
        where: dataset.submission_status != :draft,
        preload: [:business, :technical, access_groups: [:users]]
      )

    Andi.Repo.all(query)
    |> Enum.map(fn dataset ->
      %{
        id: dataset.id,
        dataTitle: dataset.business.dataTitle,
        orgTitle: dataset.business.orgTitle,
        systemName: dataset.technical.systemName,
        is_public: not dataset.technical.private,
        access_groups: dataset.access_groups,
        org_id: dataset.technical.orgId,
        keywords: dataset.business.keywords
      }
    end)
  end

  defp get_users_in_access_groups(access_groups) do
    access_groups
    |> Enum.map(fn access_group -> access_group.users end)
    |> Enum.concat()
    |> Enum.map(fn user -> user.email end)
  end

  defp get_users_in_org(id) do
    query =
      from(org in Organization,
        select: org,
        where: org.id == ^id,
        preload: [:users]
      )

    Andi.Repo.all(query)
    |> Enum.map(fn org -> org.users end)
    |> Enum.at(0)
    |> Enum.map(fn user -> user.email end)
  end
end
