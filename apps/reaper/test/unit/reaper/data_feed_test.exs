defmodule Reaper.DataFeedTest do
  use ExUnit.Case
  use Placebo

  alias Reaper.{Cache, DataFeed, Decoder, Extractor, Loader, UrlBuilder, Persistence}

  @dataset_id "12345-6789"
  @reaper_config FixtureHelper.new_reaper_config(%{
                   dataset_id: @dataset_id,
                   sourceType: "batch",
                   cadence: 100
                 })
  @cache_name String.to_atom("#{@dataset_id}_feed")

  describe("handle_info calls Persistence.record_last_fetched_timestamp") do
    setup do
      allow(UrlBuilder.build(any()), return: :does_not_matter)
      allow(Extractor.extract(any(), any()), return: :does_not_matter)
      allow(Decoder.decode(any(), any()), return: :does_not_matter)
      allow(Cache.dedupe(any(), any()), return: :does_not_matter)
      allow(Loader.load(any(), any(), any()), return: :does_not_matter)

      :ok
    end

    test "when given the empty list of dataset records" do
      allow(Cache.cache(any(), any()), return: [])
      allow(Persistence.record_last_fetched_timestamp(any(), any()), return: :does_not_matter)

      DataFeed.process(@reaper_config, @cache_name)

      assert_called(Persistence.record_last_fetched_timestamp(@dataset_id, any()))
    end

    test "when given the list of dataset records with no failures" do
      records = [
        {:ok, %{vehicle_id: 1, description: "whatever"}},
        {:ok, %{vehicle_id: 2, description: "more stuff"}}
      ]

      allow(Cache.cache(any(), any()), return: records)
      allow(Persistence.record_last_fetched_timestamp(any(), any()), return: :does_not_matter)

      DataFeed.process(@reaper_config, @cache_name)

      assert_called(Persistence.record_last_fetched_timestamp(@dataset_id, any()))
    end

    test "when given the list of dataset records with a single failure" do
      records = [
        {:ok, %{vehicle_id: 1, description: "whatever"}},
        {:error, "failed to load into kafka"}
      ]

      allow(Cache.cache(any(), any()), return: records)
      allow(Persistence.record_last_fetched_timestamp(any(), any()), return: :does_not_matter)

      DataFeed.process(@reaper_config, @cache_name)

      assert_called(Persistence.record_last_fetched_timestamp(@dataset_id, any()))
    end

    test "when given the list of dataset records with all failures (something is really wrong), it does not record to redis" do
      records = [
        {:error, "failed to load into kafka"},
        {:error, "failed to load into kafka"}
      ]

      allow(Cache.cache(any(), any()), return: records)
      allow(Persistence.record_last_fetched_timestamp(any(), any()), return: :does_not_matter)

      DataFeed.process(@reaper_config, @cache_name)

      assert not called?(Persistence.record_last_fetched_timestamp(any(), any()))
    end
  end
end
