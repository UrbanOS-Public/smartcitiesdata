defmodule AndiWeb.ReportsController do
  use AndiWeb, :controller

  access_levels(download_report: [:private])

  def download_report(conn, _params) do
    # Note: Each list is a different row
    csv = CSV.encode([["Dataset ID", "Users"], ["12345", "user1@fakemail.com, user2@fakemail.com"]]) |> Enum.to_list() |> to_string()

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"record.csv\"")
    |> resp(200, csv)
  end
end
