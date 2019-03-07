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
  alias SCOS.RegistryMessage

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

      assert Process.read_timer(timer_ref) == @dataset.technical.cadence
    end
  end

  describe "update scenarios" do
    setup do
      TestHelper.start_horde(Reaper.Registry, Reaper.Horde.Supervisor)

      :ok
    end

    test "dataset updates replace old state" do
      {:ok, pid} = DataFeed.start_link(@data_feed_args)

      persisted_dataset =
        FixtureHelper.new_dataset(%{
          id: @dataset_id,
          operational: %{organization: "persisted", status: "Fail"}
        })

      dataset_update =
        FixtureHelper.new_dataset(%{id: @dataset_id, operational: %{organization: "persisted", status: "Success"}})

      expected_dataset =
        FixtureHelper.new_dataset(%{id: @dataset_id, operational: %{organization: "persisted", status: "Success"}})

      expected_json =
        expected_dataset
        |> Map.from_struct()
        |> Jason.encode!()

      DataFeed.update(pid, dataset_update)

      # Force the handle cast to block inside this test
      assert expected_dataset == DataFeed.get(pid).dataset
    end
  end
end
