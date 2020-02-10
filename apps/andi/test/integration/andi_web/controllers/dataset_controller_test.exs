defmodule Andi.CreateDatasetTest do
  use ExUnit.Case
  use Divo
  use Tesla

  import SmartCity.TestHelper, only: [eventually: 1]
  import SmartCity.Event, only: [dataset_disable: 0, dataset_delete: 0]
  import Andi
  alias SmartCity.TestDataGenerator, as: TDG

  plug(Tesla.Middleware.BaseUrl, "http://localhost:4000")
  @kafka_broker Application.get_env(:andi, :kafka_broker)

  describe "dataset disable" do
    test "sends dataset:disable event" do
      dataset = TDG.create_dataset(%{})
      {:ok, _} = create(dataset)

      eventually(fn ->
        {:ok, value} = Brook.get(instance_name(), :dataset, dataset.id)
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

  describe "dataset delete" do
    test "sends dataset:delete event" do
      dataset = TDG.create_dataset(%{})
      {:ok, _} = create(dataset)

      eventually(fn ->
        {:ok, value} = Brook.get(instance_name(), :dataset, dataset.id)
        assert value != nil
      end)

      post("/api/v1/dataset/delete", %{id: dataset.id} |> Jason.encode!(),
        headers: [{"content-type", "application/json"}]
      )

      eventually(fn ->
        values =
          Elsa.Fetch.fetch(@kafka_broker, "event-stream")
          |> elem(2)
          |> Enum.filter(fn message ->
            message.key == dataset_delete() && String.contains?(message.value, dataset.id)
          end)

        assert 1 = length(values)
      end)
    end
  end

  defp create(dataset) do
    struct = Jason.encode!(dataset)
    put("/api/v1/dataset", struct, headers: [{"content-type", "application/json"}])
  end
end
