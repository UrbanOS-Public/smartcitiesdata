defmodule AndiWeb.EditControllerTest do
  use AndiWeb.ConnCase

  @url_path "/datasets"

  describe "EditController" do
    test "gives 404 if dataset is not found", %{conn: conn} do
      DatasetHelpers.ensure_dataset_removed_from_repo("111")
      conn = get(conn, "#{@url_path}/111")
      assert response(conn, 404)
    end

    test "gives 200 if dataset is found", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset([])
      DatasetHelpers.add_dataset_to_repo(dataset)

      conn = get(conn, "#{@url_path}/#{dataset.id}")
      assert response(conn, 200)
    end
  end
end
