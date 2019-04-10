defmodule Andi.CreateDatasetTest do
  use ExUnit.Case
  use Divo
  use Tesla

  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  plug Tesla.Middleware.BaseUrl, "http://localhost:4000"

  setup do
    expected = TDG.create_dataset(%{})
    {:ok, response} = create(expected)
    {:ok, response: response, expected: expected}
  end

  describe "dataset creation" do
    test "responds with a 201 on create", %{response: response} do
      assert response.status == 201
    end

    test "persists dataset for downstream use", %{expected: expected} do
      assert {:ok, actual} = Dataset.get(expected.id)
      assert actual.technical.systemName == expected.technical.systemName
    end
  end

  describe "dataset retrieval" do
    test "returns all datasets", %{expected: expected} do
      result = get("/api/v1/datasets")

      datasets =
        elem(result, 1).body
        |> Jason.decode!()
        |> Enum.map(fn x ->
          {:ok, dataset} = Dataset.new(x)
          dataset
        end)

      assert Enum.find(datasets, fn dataset -> expected.id == dataset.id end)
    end
  end

  defp create(dataset) do
    struct = Jason.encode!(dataset)

    put("/api/v1/dataset", struct, headers: [{"content-type", "application/json"}])
  end
end
