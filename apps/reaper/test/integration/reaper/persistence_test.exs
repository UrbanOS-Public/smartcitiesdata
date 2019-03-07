defmodule PersistenceTest do
  use ExUnit.Case
  alias Reaper.Persistence
  alias SCOS.RegistryMessage

  @dataset_id "12345-3323"

  setup_all do
    Application.ensure_all_started(:reaper)

    on_exit(fn ->
      Application.stop(:reaper)
    end)

    :ok
  end

  setup do
    Redix.command!(:redix, ["FLUSHALL"])
    :ok
  end

  test "get should return nil when dataset does not exist" do
    actual_dataset = Persistence.get("123456")
    assert nil == actual_dataset
  end

  test "Dataset saves data to Redis" do
    dataset = FixtureHelper.new_dataset(%{id: @dataset_id})
    Persistence.persist(dataset)

    {:ok, actual} =
      Redix.command!(:redix, ["GET", "reaper:dataset:#{dataset.id}"])
      |> Jason.decode!(keys: :atoms)
      |> SCOS.RegistryMessage.new()

    assert actual.id == dataset.id
    assert actual.business == dataset.business
    assert actual.technical == dataset.technical
  end

  test "get should return a single dataset" do
    dataset = FixtureHelper.new_dataset(%{id: @dataset_id})
    dataset_json_string = RegistryMessage.encode!(dataset)

    Redix.command!(:redix, ["SET", "reaper:dataset:#{dataset.id}", dataset_json_string])

    actual_dataset = Persistence.get(dataset.id)
    assert actual_dataset == dataset
  end

  test "getall should return all datasets" do
    dataset = FixtureHelper.new_dataset(%{id: @dataset_id})
    dataset2 = FixtureHelper.new_dataset(%{id: "987"})

    Redix.command!(:redix, ["SET", "reaper:dataset:#{dataset.id}", RegistryMessage.encode!(dataset)])
    Redix.command!(:redix, ["SET", "reaper:dataset:#{dataset2.id}", RegistryMessage.encode!(dataset2)])

    actual_datasets = Persistence.get_all() |> Enum.sort()
    assert actual_datasets == [dataset, dataset2] |> Enum.sort()
  end

  test "get all returns empty list if no keys exist" do
    assert [] == Persistence.get_all()
  end
end
