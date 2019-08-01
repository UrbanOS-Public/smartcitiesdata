defmodule Andi.CreateDatasetTest do
  use ExUnit.Case
  use Divo
  use Tesla

  import SmartCity.TestHelper, only: [eventually: 1]
  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  plug Tesla.Middleware.BaseUrl, "http://localhost:4000"
  @kafka_broker Application.get_env(:andi, :kafka_broker)

  setup_all do
    Redix.command!(:smart_city_registry, ["FLUSHALL"])
    expected = TDG.create_dataset(technical: %{orgName: "org1"}, business: %{dataName: "controller-integration"})
    {:ok, response} = create(expected)
    {:ok, response: response, expected: expected}
  end

  describe "dataset creation" do
    test "responds with a 201 on create", %{response: response} do
      assert response.status == 201
    end

    test "persists dataset for downstream use", %{expected: expected} do
      eventually(fn ->
        assert {:ok, actual} = Brook.get(:dataset, expected.id)
        assert actual.technical.dataName == "org1__controller-integration"
      end)
    end

    test "sends dataset to event stream", %{expected: expected} do
      [%{key: key, value: value}] =
        Elsa.Fetch.search_values(@kafka_broker, "event-stream", "controller") |> Enum.to_list()

      assert key == "dataset:update"
      assert value =~ "controller"
      assert value == Jason.encode!(expected)
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
