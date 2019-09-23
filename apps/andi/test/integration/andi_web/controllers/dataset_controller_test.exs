defmodule Andi.CreateDatasetTest do
  use ExUnit.Case
  use Divo
  use Tesla

  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]
  import SmartCity.Event, only: [dataset_disable: 0]
  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  plug(Tesla.Middleware.BaseUrl, "http://localhost:4000")
  @kafka_broker Application.get_env(:andi, :kafka_broker)

  setup_all do
    Redix.command!(:smart_city_registry, ["FLUSHALL"])

    expected =
      TDG.create_dataset(
        technical: %{orgName: "org1"},
        technical: %{dataName: "controller-integration"}
      )

    {:ok, response} = create(expected)
    {:ok, response: response, expected: expected}
  end

  describe "dataset creation" do
    test "responds with a 201 on create", %{response: response} do
      assert response.status == 201
    end

    test "persists dataset for downstream use", %{expected: expected} do
      eventually(fn ->
        assert {:ok, %{technical: %{dataName: "controller-integration"}}} = Brook.get(:dataset, expected.id)
      end)
    end

    test "sends dataset to event stream", %{expected: expected} do
      eventually(fn ->
        [%{key: "dataset:update", value: _value}] =
          Elsa.Fetch.search_values(@kafka_broker, "event-stream", expected.id) |> Enum.to_list()
      end)
    end
  end

  describe "dataset retrieval" do
    test "returns all datasets", %{expected: expected} do
      eventually(
        fn ->
          result = get("/api/v1/datasets")

          datasets =
            elem(result, 1).body
            |> Jason.decode!()
            |> Enum.map(fn x ->
              {:ok, dataset} = Dataset.new(x)
              dataset
            end)

          assert Enum.find(datasets, fn dataset -> expected.id == dataset.id end)
        end,
        2000,
        10
      )
    end
  end

  describe "dataset disable" do
    test "sends dataset:disable event" do
      dataset = TDG.create_dataset(%{})
      {:ok, _} = create(dataset)

      eventually(fn ->
        {:ok, value} = Brook.get(:dataset, dataset.id)
        assert value != nil
      end)

      post("/api/v1/dataset/disable", %{id: dataset.id} |> Jason.encode!(),
        headers: [{"content-type", "application/json"}]
      )

      eventually(fn ->
        values =
          Elsa.Fetch.fetch(@kafka_broker, "event-stream")
          |> elem(2)
          |> Enum.filter(fn message ->
            message.key == dataset_disable() && String.contains?(message.value, dataset.id)
          end)

        assert 1 == length(values)
      end)
    end
  end

  defp create(dataset) do
    struct = Jason.encode!(dataset)

    put("/api/v1/dataset", struct, headers: [{"content-type", "application/json"}])
  end
end
