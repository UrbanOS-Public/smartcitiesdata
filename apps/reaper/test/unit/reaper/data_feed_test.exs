defmodule Reaper.DataFeedTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.{Cache, DataFeed, Decoder, Extractor, Loader, UrlBuilder, Persistence}

  @dataset_id "12345-6789"
  @reaper_config FixtureHelper.new_reaper_config(%{dataset_id: @dataset_id, sourceType: "batch", cadence: 100})
  @data_feed_args %{
    pids: %{
      name: String.to_atom("#{@dataset_id}_feed"),
      cache: String.to_atom("#{@dataset_id}_cache")
    },
    reaper_config: @reaper_config
  }

  describe "handle_info given a state that includes a reaper config struct" do
    test "schedules itself on the provided cadence" do
      expect(UrlBuilder.build(any()), return: :does_not_matter)
      expect(Extractor.extract(any()), return: :does_not_matter)
      expect(Decoder.decode(any(), any(), any()), return: :does_not_matter)
      expect(Cache.dedupe(any(), any()), return: :does_not_matter)
      expect(Loader.load(any(), any(), any()), return: :does_not_matter)
      expect(Cache.cache(any(), any()), return: [])
      expect(Persistence.record_last_fetched_timestamp(any(), any()), return: :does_not_matter)

      {:noreply, %{timer_ref: timer_ref}} = DataFeed.handle_info(:work, @data_feed_args)

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
      {:ok, pid} = DataFeed.start_link(@data_feed_args)

      reaper_config_update =
        FixtureHelper.new_reaper_config(%{dataset_id: @dataset_id, sourceUrl: "persisted", sourceFormat: "Success"})

      expected_reaper_config =
        FixtureHelper.new_reaper_config(%{dataset_id: @dataset_id, sourceUrl: "persisted", sourceFormat: "Success"})

      DataFeed.update(pid, reaper_config_update)

      # Force the handle cast to block inside this test
      assert expected_reaper_config == DataFeed.get(pid).reaper_config
    end
  end

  describe "handle_info calls Persistence.record_last_fetched_timestamp" do
    setup do
      allow(UrlBuilder.build(any()), return: :does_not_matter)
      allow(Extractor.extract(any()), return: :does_not_matter)
      allow(Decoder.decode(any(), any(), any()), return: :does_not_matter)
      allow(Cache.dedupe(any(), any()), return: :does_not_matter)
      allow(Loader.load(any(), any(), any()), return: :does_not_matter)

      :ok
    end

    test "when given the an empty list of dataset records" do
      allow(Cache.cache(any(), any()), return: [])
      allow(Persistence.record_last_fetched_timestamp(any(), any()), return: :does_not_matter)

      DataFeed.handle_info(:work, @data_feed_args)

      assert_called(Persistence.record_last_fetched_timestamp(@dataset_id, any()))
    end

    test "when given the list of dataset records with no failures" do
      records = [
        {:ok, %{vehicle_id: 1, description: "whatever"}},
        {:ok, %{vehicle_id: 2, description: "more stuff"}}
      ]

      allow(Cache.cache(any(), any()), return: records)
      allow(Persistence.record_last_fetched_timestamp(any(), any()), return: :does_not_matter)

      DataFeed.handle_info(:work, @data_feed_args)

      assert_called(Persistence.record_last_fetched_timestamp(@dataset_id, any()))
    end

    test "when given the list of dataset records with a single failure" do
      records = [
        {:ok, %{vehicle_id: 1, description: "whatever"}},
        {:error, "failed to load into kafka"}
      ]

      allow(Cache.cache(any(), any()), return: records)
      allow(Persistence.record_last_fetched_timestamp(any(), any()), return: :does_not_matter)

      DataFeed.handle_info(:work, @data_feed_args)

      assert_called(Persistence.record_last_fetched_timestamp(@dataset_id, any()))
    end

    test "when given the list of dataset records with all failures (something is really wrong), it does not record to redis" do
      records = [
        {:error, "failed to load into kafka"},
        {:error, "failed to load into kafka"}
      ]

      allow(Cache.cache(any(), any()), return: records)
      allow(Persistence.record_last_fetched_timestamp(any(), any()), return: :does_not_matter)

      DataFeed.handle_info(:work, @data_feed_args)

      assert not called?(Persistence.record_last_fetched_timestamp(any(), any()))
    end
  end

  describe "When calculating the next runtime" do
    test "it is scheduled instantly if it has not be scheduled for a period of time longer than the cadence" do
      one_hundred_seconds_ago = DateTime.add(DateTime.utc_now(), -100, :second)
      allow(Persistence.get_last_fetched_timestamp(any()), return: one_hundred_seconds_ago)
      new_dataset = FixtureHelper.new_reaper_config(%{dataset_id: @dataset_id, cadence: 100_000})
      assert DataFeed.calculate_next_run_time(new_dataset) == 0
    end

    test "it is scheduled based upon the difference between now and cadence" do
      ten_seconds_ago = DateTime.add(DateTime.utc_now(), -10, :second)
      allow(Persistence.get_last_fetched_timestamp(any()), return: ten_seconds_ago)
      new_dataset = FixtureHelper.new_reaper_config(%{dataset_id: @dataset_id, cadence: 100_000})

      assert abs(DataFeed.calculate_next_run_time(new_dataset) - 90_000) < 50
    end

    test "it is scheduled instantly if it has not be fetched before" do
      allow(Persistence.get_last_fetched_timestamp(any()), return: nil)
      new_dataset = FixtureHelper.new_reaper_config(%{dataset_id: @dataset_id, cadence: 100_000})

      assert DataFeed.calculate_next_run_time(new_dataset) == 0
    end
  end
end
