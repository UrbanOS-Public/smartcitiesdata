defmodule Reaper.DataFeedTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.Cache
  alias Reaper.DataFeed
  alias Reaper.Decoder
  alias Reaper.Extractor
  alias Reaper.Loader
  alias Reaper.UrlBuilder
  alias Reaper.Persistence

  @dataset_id "12345-6789"
  @reaper_config FixtureHelper.new_reaper_config(%{id: @dataset_id})
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
      expect(Decoder.decode(any(), any()), return: :does_not_matter)
      expect(Cache.dedupe(any(), any()), return: :does_not_matter)
      expect(Loader.load(any(), any()), return: :does_not_matter)
      expect(Cache.cache(any(), any()), return: :does_not_matter)
      expect(Persistence.record_last_fetched_timestamp(any(), any(), any()), return: :does_not_matter)

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
      {:ok, pid} = DataFeed.start_link(@data_feed_args)

      reaper_config_update =
        FixtureHelper.new_reaper_config(%{id: @dataset_id, sourceUrl: "persisted", sourceFormat: "Success"})

      expected_reaper_config =
        FixtureHelper.new_reaper_config(%{id: @dataset_id, sourceUrl: "persisted", sourceFormat: "Success"})

      DataFeed.update(pid, reaper_config_update)

      # Force the handle cast to block inside this test
      assert expected_reaper_config == DataFeed.get(pid).reaper_config
    end
  end
end
