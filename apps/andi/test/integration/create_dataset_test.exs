defmodule Andi.CreateDatasetTest do
  use ExUnit.Case
  use Divo

  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  describe "successful dataset creation" do
    test "responds with a 201" do
      {:ok, response} =
        %{}
        |> TDG.create_dataset()
        |> create()

      assert response.status_code == 201
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

    "http://localhost:4000/api/v1/dataset"
    |> HTTPoison.put(struct, [{"content-type", "application/json"}])
  end
end
