defmodule PersistenceTest do
  use ExUnit.Case
  alias Reaper.Persistence
  alias Reaper.Sickle

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

  test "Sickle saves data to Redis" do
    sickle = FixtureHelper.new_sickle(%{dataset_id: @dataset_id})
    Persistence.persist(sickle)

    actual_map =
      Redix.command!(:redix, ["GET", "reaper:dataset:#{sickle.dataset_id}"])
      |> Jason.decode!(keys: :atoms)

    actual = struct(%Sickle{}, actual_map)
    assert actual == sickle
  end

  test "get should return a single sickle" do
    sickle = FixtureHelper.new_sickle(%{dataset_id: @dataset_id})
    sickle_json_string = Sickle.encode!(sickle)

    Redix.command!(:redix, ["SET", "reaper:dataset:#{sickle.dataset_id}", sickle_json_string])

    actual_sickle = Persistence.get(sickle.dataset_id)
    assert actual_sickle == sickle
  end

  test "getall should return all sickles" do
    sickle = FixtureHelper.new_sickle(%{dataset_id: @dataset_id})
    sickle2 = FixtureHelper.new_sickle(%{dataset_id: "987"})

    Redix.command!(:redix, ["SET", "reaper:dataset:#{sickle.dataset_id}", Sickle.encode!(sickle)])
    Redix.command!(:redix, ["SET", "reaper:dataset:#{sickle2.dataset_id}", Sickle.encode!(sickle2)])

    actual_sickles = Persistence.get_all() |> Enum.sort()
    assert actual_sickles == [sickle, sickle2] |> Enum.sort()
  end

  test "get all returns empty list if no keys exist" do
    assert [] == Persistence.get_all()
  end
end
