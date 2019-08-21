defmodule Reaper.ConfigServerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  use Placebo

  alias Reaper.ConfigServer
  alias Reaper.DataFeedScheduler

  @name_space "reaper:reaper_config:"

  setup do
    TestHelper.start_horde(Reaper.Registry, Reaper.Horde.Supervisor)

    allow(DataFeedScheduler.start_link(any()), return: :ignore)
    allow(DataFeedScheduler.update(any(), any()), return: :does_not_matter)

    :ok
  end

  describe "on registry message received with no previous reaper configs" do
    test "the config server spins up several new supervisors for streaming and ingest datasets" do
      allow(Redix.command!(:redix, ["KEYS", @name_space <> "*"]), return: [])
      allow(Redix.command!(:redix, any()), return: :does_not_matter)

      allow(Reaper.Persistence.get_last_fetched_timestamp(any()),
        return: DateTime.utc_now(),
        meck_options: [:passthrough]
      )

      ConfigServer.start_link([])

      ConfigServer.process_reaper_config(
        FixtureHelper.new_reaper_config(%{
          dataset_id: "12345-6789",
          sourceType: "ingest",
          cadence: 30_000,
          allow_duplicates: false
        })
      )

      ConfigServer.process_reaper_config(
        FixtureHelper.new_reaper_config(%{dataset_id: "23456-7891", sourceType: "stream", cadence: 10_000})
      )

      ConfigServer.process_reaper_config(
        FixtureHelper.new_reaper_config(%{dataset_id: "34567-8912", sourceType: "stream", cadence: 100_000})
      )

      assert TestUtils.feed_supervisor_count() == 3
      assert TestUtils.child_count(Cachex) == 1
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

  describe "on registry message received with previous reaper configs" do
    test "the config server updates an existing data feed" do
      allow(Redix.command!(:redix, ["KEYS", @name_space <> "*"]), return: [])
      ConfigServer.start_link([])

      new_url = "https://first-url-part-deux.com"

      dataset_id = "12345-6789"

      reaper_config =
        FixtureHelper.new_reaper_config(%{
          dataset_id: dataset_id,
          sourceType: "stream",
          cadence: 50_000,
          allow_duplicates: false
        })

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
          cadence: 50_000,
          allow_duplicates: false
        })
      )

      assert TestUtils.feed_supervisor_count() == 1
      assert TestUtils.child_count(Cachex) == 1

      eventual_pids = TestUtils.get_child_pids_for_feed_supervisor(:"12345-6789")

      assert eventual_pids != :undefined
      assert eventual_pids == initial_pids

      assert_called Reaper.DataFeedScheduler.update(any(), %{sourceUrl: new_url})
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
        FixtureHelper.new_reaper_config(%{
          dataset_id: "12345-6789",
          sourceType: "ingest",
          cadence: 10_000,
          allow_duplicates: false
        })
      )

      assert TestUtils.feed_supervisor_count() == 1
      assert TestUtils.child_count(Cachex) == 1

      allow Horde.Registry.lookup(any(), any()), return: :undefined, meck_options: [:passthrough]

      ConfigServer.process_reaper_config(
        FixtureHelper.new_reaper_config(%{
          dataset_id: "12345-6789",
          technical: %{sourceUrl: "whatever"},
          allow_duplicates: false
        })
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
      reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: dataset_id, sourceType: "ingest", cadence: "never"})

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
      reaper_config = FixtureHelper.new_reaper_config(%{dataset_id: dataset_id, sourceType: "ingest", cadence: 0})

      allow(Reaper.Persistence.get_last_fetched_timestamp(any()),
        return: DateTime.utc_now(),
        meck_options: [:passthrough]
      )

      assert capture_log(fn ->
               ConfigServer.process_reaper_config(reaper_config)
             end) =~ "Inviable configuration"
    end
  end
end
