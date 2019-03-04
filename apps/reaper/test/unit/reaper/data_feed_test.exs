defmodule Reaper.DataFeedTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.Cache
  alias Reaper.DataFeed
  alias Reaper.Decoder
  alias Reaper.Extractor
  alias Reaper.Loader
  alias Reaper.UrlBuilder
  alias Reaper.Recorder

  @dataset_id "12345-6789"
  @dataset FixtureHelper.new_dataset(%{id: @dataset_id})
  @data_feed_args %{
    pids: %{
      name: String.to_atom("#{@dataset_id}_feed"),
      cache: String.to_atom("#{@dataset_id}_cache")
    },
    dataset: @dataset
  }

  describe ".handle_info given a state that includes a dataset struct" do
    test "schedules itself on the provided cadence" do
      expect(UrlBuilder.build(any()), return: :does_not_matter)
      expect(Extractor.extract(any()), return: :does_not_matter)
      expect(Decoder.decode(any(), any()), return: :does_not_matter)
      expect(Cache.dedupe(any(), any()), return: :does_not_matter)
      expect(Loader.load(any(), any()), return: :does_not_matter)
      expect(Cache.cache(any(), any()), return: :does_not_matter)
      expect(Recorder.record_last_fetched_timestamp(any(), any(), any()), return: :does_not_matter)

      {:noreply, %{timer_ref: timer_ref}} = DataFeed.handle_info(:work, @data_feed_args)

      assert Process.read_timer(timer_ref) == @dataset.operational.cadence
    end
  end

  describe "update scenarios" do
    setup do
      TestHelper.start_horde(Reaper.Registry, Reaper.Horde.Supervisor)

      :ok
    end

    test "generically updates the feed state" do
      {:ok, pid} = DataFeed.start_link(@data_feed_args)

      old_state = DataFeed.get(pid)
      DataFeed.update(pid, %{key: "key_id"})
      new_state = DataFeed.get(pid)

      assert old_state != new_state
      assert Map.get(new_state, :key) == "key_id"
    end

    test "updates dataset operational data without wiping out old data" do
      {:ok, pid} = DataFeed.start_link(@data_feed_args)

      %{
        dataset: %Dataset{
          operational: %{
            sourceFormat: old_source_format
          }
        }
      } = old_state = DataFeed.get(pid)

      DataFeed.update(
        pid,
        %{
          dataset: %{
            operational: %{cadence: 200_000}
          }
        }
      )

      %{
        dataset: %Dataset{
          operational: %{
            sourceFormat: new_source_format,
            cadence: cadence
          }
        }
      } = new_state = DataFeed.get(pid)

      assert new_state != old_state
      assert cadence == 200_000
      assert new_source_format == old_source_format
    end
  end
end
