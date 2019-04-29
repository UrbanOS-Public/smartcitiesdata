defmodule Reaper.DataFeedServerServerTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.{DataFeedServer, Persistence}

  @dataset_id "12345-6789"
  @reaper_config FixtureHelper.new_reaper_config(%{
                   dataset_id: @dataset_id,
                   sourceType: "batch",
                   cadence: 100
                 })
  @data_feed_args %{
    pids: %{
      name: String.to_atom("#{@dataset_id}_feed"),
      cache: String.to_atom("#{@dataset_id}_cache")
    },
    reaper_config: @reaper_config
  }

  describe "handle_info given a state that includes a reaper config struct" do
    test "schedules itself on the provided cadence" do
      expect Reaper.DataFeed.process(any(), any()), return: :does_not_matter

      {:noreply, %{timer_ref: timer_ref}} = DataFeedServer.handle_info(:work, @data_feed_args)

      assert Process.read_timer(timer_ref) == @reaper_config.cadence
    end
  end

  describe "update scenarios" do
    setup do
      TestHelper.start_horde(Reaper.Registry, Reaper.Horde.Supervisor)

      :ok
    end

    test "reaper config updates replace old state" do
      allow(Redix.command!(any(), any()), return: ~s({"timestamp": "2019-03-21 17:12:51.585273Z"}))

      {:ok, pid} = DataFeedServer.start_link(@data_feed_args)

      reaper_config_update =
        FixtureHelper.new_reaper_config(%{
          dataset_id: @dataset_id,
          sourceUrl: "persisted",
          sourceFormat: "Success"
        })

      expected_reaper_config =
        FixtureHelper.new_reaper_config(%{
          dataset_id: @dataset_id,
          sourceUrl: "persisted",
          sourceFormat: "Success"
        })

      DataFeedServer.update(pid, reaper_config_update)

      # Force the handle cast to block inside this test
      assert expected_reaper_config == DataFeedServer.get(pid).reaper_config
    end
  end

  describe "calculate_next_run_time/1" do
    test "calculates immediate runtime if time since last fetch exceeds cadence" do
      one_hundred_seconds_ago = DateTime.add(DateTime.utc_now(), -100, :second)
      allow(Persistence.get_last_fetched_timestamp(any()), return: one_hundred_seconds_ago)
      new_dataset = FixtureHelper.new_reaper_config(%{dataset_id: @dataset_id, cadence: 100_000})

      assert DataFeedServer.calculate_next_run_time(new_dataset) == 0
    end

    test "calculates milliseconds until next runtime if time since last fetch doesn't exceed cadence" do
      ten_seconds_ago = DateTime.add(DateTime.utc_now(), -10, :second)
      allow(Persistence.get_last_fetched_timestamp(any()), return: ten_seconds_ago)
      new_dataset = FixtureHelper.new_reaper_config(%{dataset_id: @dataset_id, cadence: 100_000})

      assert abs(DataFeedServer.calculate_next_run_time(new_dataset) - 90_000) < 50
    end

    test "calculates immediate runtime if never previously fetched" do
      allow(Persistence.get_last_fetched_timestamp(any()), return: nil)
      new_dataset = FixtureHelper.new_reaper_config(%{dataset_id: @dataset_id, cadence: 100_000})

      assert DataFeedServer.calculate_next_run_time(new_dataset) == 0
    end

    test "calculates immediate runtime if cadence is 'once' and never previously fetched" do
      allow(Persistence.get_last_fetched_timestamp(any()), return: nil)
      new_dataset = FixtureHelper.new_reaper_config(%{dataset_id: @dataset_id, cadence: "once"})

      assert DataFeedServer.calculate_next_run_time(new_dataset) == 0
    end

    test "calculates no runtime if cadence is 'once' and has been previously fetched" do
      previously = DateTime.add(DateTime.utc_now(), -3600, :second)
      allow(Persistence.get_last_fetched_timestamp(any()), return: previously)
      new_dataset = FixtureHelper.new_reaper_config(%{dataset_id: @dataset_id, cadence: "once"})

      assert DataFeedServer.calculate_next_run_time(new_dataset) == nil
    end
  end
end
