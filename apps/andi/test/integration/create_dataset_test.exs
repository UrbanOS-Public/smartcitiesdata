defmodule Andi.CreateDatasetTest do
  use ExUnit.Case
  use Divo
  use Tesla

  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  plug Tesla.Middleware.BaseUrl, "http://localhost:4000"

  describe "successful dataset creation" do
    test "responds with a 201" do
      {:ok, response} =
        %{}
        |> TDG.create_dataset()
        |> create()

      assert response.status == 201
    end

    test "persists dataset for downstream use" do
      expected = TDG.create_dataset(%{})
      create(expected)

      assert {:ok, actual} = Dataset.get(expected.id)
      assert actual.technical.systemName == expected.technical.systemName
    end
  end

  defp create(dataset) do
    struct = Jason.encode!(dataset)

    put("/api/v1/dataset", struct, headers: [{"content-type", "application/json"}])
  end
end
