defmodule PersistenceTest do
  use ExUnit.Case
  alias Reaper.Persistence
  alias Reaper.ReaperConfig

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

  test "get should return nil when reaper config does not exist" do
    assert nil == Persistence.get("123456")
  end

  test "ReaperConfig saves data to Redis" do
    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: @dataset_id})
    Persistence.persist(reaper_config)

    actual_map =
      Redix.command!(:redix, ["GET", "reaper:reaper_config:#{reaper_config.dataset_id}"])
      |> Jason.decode!(keys: :atoms)

    actual = struct(%ReaperConfig{}, actual_map)
    assert actual == reaper_config
  end

  test "get should return a single reaper_config" do
    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: @dataset_id})
    reaper_config_json_string = ReaperConfig.encode!(reaper_config)

    Redix.command!(:redix, ["SET", "reaper:reaper_config:#{reaper_config.dataset_id}", reaper_config_json_string])

    actual_reaper_config = Persistence.get(reaper_config.dataset_id)
    assert actual_reaper_config == reaper_config
  end

  test "getall should return all reaper_configs" do
    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: @dataset_id})
    reaper_config2 = FixtureHelper.new_reaper_config(%{dataset_id: "987"})

    Redix.command!(:redix, [
      "SET",
      "reaper:reaper_config:#{reaper_config.dataset_id}",
      ReaperConfig.encode!(reaper_config)
    ])

    Redix.command!(:redix, [
      "SET",
      "reaper:reaper_config:#{reaper_config2.dataset_id}",
      ReaperConfig.encode!(reaper_config2)
    ])

    actual_reaper_configs = Persistence.get_all() |> Enum.sort()
    assert actual_reaper_configs == [reaper_config, reaper_config2] |> Enum.sort()
  end

  test "get all returns empty list if no keys exist" do
    assert [] == Persistence.get_all()
  end
end
