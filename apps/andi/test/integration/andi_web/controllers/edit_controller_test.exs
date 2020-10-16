defmodule AndiWeb.EditControllerTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  alias Andi.InputSchemas.Datasets
  alias SmartCity.TestDataGenerator, as: TDG

  @url_path "/datasets"

  describe "EditController" do
    test "gives 404 if dataset is not found", %{conn: conn} do
      conn = get(conn, "#{@url_path}/#{UUID.uuid4()}")

      assert response(conn, 404)
    end

    test "gives 200 if dataset is found", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)

      conn = get(conn, "#{@url_path}/#{dataset.id}")
      assert response(conn, 200)
    end
  end
end
