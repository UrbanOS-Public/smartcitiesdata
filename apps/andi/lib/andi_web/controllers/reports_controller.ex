defmodule AndiWeb.ReportsController do
  use AndiWeb, :controller
  import Ecto.Query, only: [from: 2]
  alias Andi.Schemas.User
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset

  access_levels(download_report: [:private])

  def download_report(conn, _params) do
    # Note: Each list is a different row
    csv = CSV.encode(build_csv()) |> Enum.to_list() |> to_string()
    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"record.csv\"")
    |> resp(200, csv)
  end

  defp build_csv() do
    values = get_dataset_ids()
    |> Enum.map(fn dataset_id -> [dataset_id, get_users_with_dataset_id(dataset_id)] end)
    [["Dataset ID", "Users"] | values]
  end

  defp get_users_with_dataset_id(id) do
    get_users()
    |> Enum.filter(fn user -> Enum.any?(user.userdatasetids, fn user_dataset_id -> user_dataset_id == id end) end)
    |> Enum.map(fn user -> user.email end)
    |> Enum.join(", ")
  end

  defp get_dataset_ids() do
    query =
      from(dataset in Dataset,
      select: dataset
      )

      Andi.Repo.all(query)
      |> get_dataset_ids()
  end

  defp get_dataset_ids(datasets) do
    datasets |> Enum.map(fn dataset -> dataset.id end)
  end

  defp get_users() do
    query =
      from(user in User,
        join: d in assoc(user, :datasets),
        preload: [datasets: d]
      )

    Andi.Repo.all(query)
    |> Enum.map(fn user -> %{email: user.email, userdatasetids: get_dataset_ids(user.datasets)} end)
  end
end
