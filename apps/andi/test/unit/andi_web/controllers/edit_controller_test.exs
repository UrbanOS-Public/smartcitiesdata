defmodule AndiWeb.EditControllerTest do
  use AndiWeb.ConnCase
  alias Andi.DatasetCache
  alias SmartCity.TestDataGenerator, as: TDG

  @url_path "/datasets"

  setup do
    GenServer.call(DatasetCache, :reset)
  end

  describe "EditController" do
    test "gives 404 if dataset is not found", %{conn: conn} do
      conn = get(conn, "#{@url_path}/111")
      assert response(conn, 404)
    end

    test "gives 200 if dataset is found", %{conn: conn} do
      dataset = TDG.create_dataset([])
      DatasetCache.put(dataset)

      conn = get(conn, "#{@url_path}/#{dataset.id}")
      assert response(conn, 200)
    end
  end
end
