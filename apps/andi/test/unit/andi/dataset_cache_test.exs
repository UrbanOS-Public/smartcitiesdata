defmodule Andi.DatasetCacheTest do
  use ExUnit.Case

  import Andi, only: [instance_name: 0]
  import SmartCity.Event, only: [dataset_update: 0]

  alias Andi.DatasetCache

  alias Brook.ViewState
  alias SmartCity.TestDataGenerator, as: TDG

  describe "with cache started" do
    setup do
      GenServer.call(DatasetCache, :reset)

      :ok
    end

    test "datasets passed to put_datasets/1 are returned by get_datasets/0" do
      datasets = Enum.map(1..3, fn _ -> TDG.create_dataset([]) end)

      DatasetCache.put_datasets(datasets)
      results = DatasetCache.get_datasets()

      Enum.each(datasets, fn dataset ->
        assert Enum.member?(results, dataset)
      end)
    end

    test "dataset passed to put_dataset/1 is returned by get_datasets/0" do
      dataset = TDG.create_dataset([])

      DatasetCache.put_dataset(dataset)

      assert DatasetCache.get_datasets() |> Enum.member?(dataset)
    end
  end

  describe "init/0 callback" do
    test "inserts datasets from the view state" do
      datasets = Enum.map(1..3, fn _ -> TDG.create_dataset([]) end)

      Brook.Test.with_event(instance_name(), fn ->
        Enum.each(datasets, fn dataset ->
          ViewState.merge(:dataset, dataset.id, dataset)
        end)
      end)

      GenServer.call(DatasetCache, :reset)

      results = DatasetCache.get_datasets()

      Enum.each(datasets, fn dataset ->
        assert Enum.member?(results, dataset)
      end)
    end
  end

  test "Event handler adds datasets to cache on dataset_update event" do
    GenServer.call(DatasetCache, :reset)

    datasets =
      Enum.map(1..3, fn _ ->
        dataset = TDG.create_dataset([])
        Brook.Event.send(instance_name(), dataset_update(), :andi_test, dataset)

        dataset
      end)

    results = DatasetCache.get_datasets()

    Enum.each(datasets, fn dataset ->
      assert Enum.member?(results, dataset)
    end)
  end
end
