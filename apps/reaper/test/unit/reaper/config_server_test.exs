defmodule Reaper.ConfigServerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  use Placebo

  alias Reaper.ConfigServer
  alias Reaper.DataFeed
  alias Reaper.ReaperConfig

  @name_space "reaper:reaper_config:"

  setup do
    TestHelper.start_horde(Reaper.Registry, Reaper.Horde.Supervisor)

    :ok
  end

  describe "on startup" do
    test "supervisors are started for persisted reaper configs" do
      reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: "123", sourceType: "batch", cadence: 10_000})
      reaper_config2 = FixtureHelper.new_reaper_config(%{dataset_id: "987", sourceType: "stream", cadence: 10_000})

      allow(Redix.command!(:redix, ["KEYS", @name_space <> "*"]), return: [@name_space <> "123", @name_space <> "987"])

      allow(Redix.command!(:redix, ["MGET", @name_space <> "123", @name_space <> "987"]),
        return: [ReaperConfig.encode!(reaper_config), ReaperConfig.encode!(reaper_config2)]
      )

      allow(Reaper.Persistence.get_last_fetched_timestamp(any()),
        return: DateTime.utc_now(),
        meck_options: [:passthrough]
      )

      ConfigServer.start_link([])

      Patiently.wait_for!(
        fn -> TestUtils.feed_supervisor_count() == 2 end,
        dwell: 100,
        max_tries: 10
      )

      Patiently.wait_for!(
        fn -> TestUtils.child_count(Cachex) == 2 end,
        dwell: 100,
        max_tries: 10
      )
    end
  end

  describe "on registry message received with no previous reaper configs" do
    test "the config server spins up several new supervisors for streaming and batch datasets" do
      allow(Redix.command!(:redix, ["KEYS", @name_space <> "*"]), return: [])
      allow(Redix.command!(:redix, any()), return: :does_not_matter)

      allow(Reaper.Persistence.get_last_fetched_timestamp(any()),
        return: DateTime.utc_now(),
        meck_options: [:passthrough]
      )

      ConfigServer.start_link([])

      ConfigServer.process_reaper_config(
        FixtureHelper.new_reaper_config(%{dataset_id: "12345-6789", sourceType: "batch", cadence: 30_000})
      )

      ConfigServer.process_reaper_config(
        FixtureHelper.new_reaper_config(%{dataset_id: "23456-7891", sourceType: "stream", cadence: 10_000})
      )

      ConfigServer.process_reaper_config(
        FixtureHelper.new_reaper_config(%{dataset_id: "34567-8912", sourceType: "stream", cadence: 100_000})
      )

      assert TestUtils.feed_supervisor_count() == 3
      assert TestUtils.child_count(Cachex) == 3
    end

    test "the config server does not create supervisors for remote datasets" do
      allow(Redix.command!(:redix, ["KEYS", @name_space <> "*"]), return: [])
      allow(Redix.command!(:redix, any()), return: :does_not_matter)

      allow(Reaper.FeedSupervisor.create_child_spec(any()),
        return: any(),
        meck_options: [:passthrough]
      )

      ConfigServer.start_link([])

      ConfigServer.process_reaper_config(FixtureHelper.new_reaper_config(%{dataset_id: "45678-9123"}))

      assert_called(Reaper.FeedSupervisor.create_child_spec(), never())
      assert TestUtils.feed_supervisor_count() == 0
      assert TestUtils.child_count(Cachex) == 0
    end
  end

  test "a reaper config is persisted when created or updated" do
    allow(Redix.command!(:redix, ["KEYS", @name_space <> "*"]), return: [])
    allow(Redix.command!(:redix, ["GET", any()]), return: '')

    reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: "12345-6789", sourceType: "batch", cadence: 1})

    reaper_config_update =
      FixtureHelper.new_reaper_config(%{
        dataset_id: reaper_config.dataset_id,
        cadence: 100,
        sourceUrl: "www.google.com",
        sourceFormat: "Success",
        sourceType: "batch",
        queryParams: %{param1: "value1"}
      })

    expect(
      Redix.command!(:redix, ["SET", @name_space <> reaper_config.dataset_id, ReaperConfig.encode!(reaper_config)]),
      return: :does_not_matter
    )

    expect(
      Redix.command!(:redix, [
        "SET",
        @name_space <> reaper_config.dataset_id,
        ReaperConfig.encode!(reaper_config_update)
      ]),
      return: :does_not_matter
    )

    ConfigServer.start_link([])
    ConfigServer.process_reaper_config(reaper_config)
    ConfigServer.process_reaper_config(reaper_config_update)
  end

  describe "on registry message received with previous reaper configs" do
    test "the config server updates an existing data feed" do
      allow(Redix.command!(:redix, ["KEYS", @name_space <> "*"]), return: [])
      ConfigServer.start_link([])

      new_url = "https://first-url-part-deux.com"

      dataset_id = "12345-6789"
      reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: dataset_id, sourceType: "stream", cadence: 50_000})

      return_json =
        reaper_config
        |> Map.from_struct()
        |> Jason.encode!()

      allow(Redix.command!(:redix, ["GET", any()]), return: return_json)
      allow(Redix.command!(:redix, any()), return: :does_not_matter)

      allow(Reaper.Persistence.get_last_fetched_timestamp(any()),
        return: DateTime.utc_now(),
        meck_options: [:passthrough]
      )

      ConfigServer.process_reaper_config(reaper_config)

      assert TestUtils.feed_supervisor_count() == 1
      assert TestUtils.child_count(Cachex) == 1

      initial_pids = TestUtils.get_child_pids_for_feed_supervisor(:"12345-6789")
      assert initial_pids != :undefined

      ConfigServer.process_reaper_config(
        FixtureHelper.new_reaper_config(%{
          dataset_id: dataset_id,
          sourceType: "stream",
          sourceUrl: new_url,
          cadence: 50_000
        })
      )

      assert TestUtils.feed_supervisor_count() == 1
      assert TestUtils.child_count(Cachex) == 1

      eventual_pids = TestUtils.get_child_pids_for_feed_supervisor(:"12345-6789")
      assert eventual_pids != :undefined
      assert eventual_pids == initial_pids

      %{
        reaper_config: %{
          sourceUrl: source_url
        }
      } = get_state(:"12345-6789_feed")

      assert source_url == new_url
    end

    test "when feed supervisor is not found update does not blow up" do
      allow(Redix.command!(:redix, ["KEYS", @name_space <> "*"]), return: [])
      allow(Redix.command!(:redix, any()), return: :does_not_matter)

      allow(Reaper.Persistence.get_last_fetched_timestamp(any()),
        return: DateTime.utc_now(),
        meck_options: [:passthrough]
      )

      ConfigServer.start_link([])

      ConfigServer.process_reaper_config(
        FixtureHelper.new_reaper_config(%{dataset_id: "12345-6789", sourceType: "batch", cadence: 10_000})
      )

      assert TestUtils.feed_supervisor_count() == 1
      assert TestUtils.child_count(Cachex) == 1

      allow Horde.Registry.lookup(any(), any()), return: :undefined, meck_options: [:passthrough]

      ConfigServer.process_reaper_config(
        FixtureHelper.new_reaper_config(%{dataset_id: "12345-6789", technical: %{sourceUrl: "whatever"}})
      )

      assert TestUtils.feed_supervisor_count() == 1
      assert TestUtils.child_count(Cachex) == 1
    end
  end

  describe "processing remote datasets" do
    test "does NOT create or update a supervisor, or persist data" do
      reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: "34567-8912", sourceType: "remote"})

      # Does Not persist data; only allow server to check for existing configs on startup
      allow(Redix.command!(:redix, ["KEYS", @name_space <> "*"]), return: [])

      allow(Reaper.Persistence.get_last_fetched_timestamp(any()),
        return: DateTime.utc_now(),
        meck_options: [:passthrough]
      )

      ConfigServer.start_link([])
      ConfigServer.process_reaper_config(reaper_config)

      # Does not start supervisors
      assert TestUtils.feed_supervisor_count() == 0
      assert TestUtils.child_count(Cachex) == 0
    end

    test "the config server raises an error if the remote dataset has a cadence of something other than never" do
      allow(Redix.command!(:redix, ["KEYS", @name_space <> "*"]), return: [])
      ConfigServer.start_link([])

      dataset_id = "12345-6789"
      reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: dataset_id, sourceType: "remote", cadence: 50_000})

      allow(Reaper.Persistence.get_last_fetched_timestamp(any()),
        return: DateTime.utc_now(),
        meck_options: [:passthrough]
      )

      assert capture_log(fn ->
               ConfigServer.process_reaper_config(reaper_config)
             end) =~ "Inviable configuration"
    end

    test "the config server raises an error if the a non-remote dataset has a cadence of never" do
      allow(Redix.command!(:redix, ["KEYS", @name_space <> "*"]), return: [])
      ConfigServer.start_link([])

      dataset_id = "12345-6789"
      reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: dataset_id, sourceType: "batch", cadence: "never"})

      allow(Reaper.Persistence.get_last_fetched_timestamp(any()),
        return: DateTime.utc_now(),
        meck_options: [:passthrough]
      )

      assert capture_log(fn ->
               ConfigServer.process_reaper_config(reaper_config)
             end) =~ "Inviable configuration"
    end

    test "the config server raises an error if a dataset has a cadence of 0" do
      allow(Redix.command!(:redix, ["KEYS", @name_space <> "*"]), return: [])
      ConfigServer.start_link([])

      dataset_id = "12345-6789"
      reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: dataset_id, sourceType: "batch", cadence: 0})

      allow(Reaper.Persistence.get_last_fetched_timestamp(any()),
        return: DateTime.utc_now(),
        meck_options: [:passthrough]
      )

      assert capture_log(fn ->
               ConfigServer.process_reaper_config(reaper_config)
             end) =~ "Inviable configuration"
    end
  end

  defp get_state(name) do
    DataFeed.get({:via, Horde.Registry, {Reaper.Registry, name}})
  end
end
