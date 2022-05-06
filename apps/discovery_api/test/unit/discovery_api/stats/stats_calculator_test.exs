defmodule DiscoveryApi.Stats.StatsCalculatorTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Stats.StatsCalculator
  alias DiscoveryApi.Data.Persistence
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Data.Mapper
  alias SmartCity.TestDataGenerator, as: TDG

  @dataset_id "eaad54e8-fcb6-4f0e-99ac-bf51887ed102"
  @completeness_key "discovery-api:completeness_calculated_date"
  @organization DiscoveryApi.Test.Helper.create_schema_organization()

  describe "produce_completeness_stats/1 positive cases" do
    setup do
      allow(RaptorService.list_access_groups_by_dataset(any(), any()), return: %{access_groups: []})
      dataset = mock_non_remote_dataset()
      allow(Model.get_all(), return: [dataset], meck_options: [:passthrough])
      allow(Persistence.persist(any(), any()), return: :does_not_matter)
      allow(Prestige.new_session(any()), return: :connection)
      allow(Prestige.query!(any(), any()), return: :results)

      allow(Prestige.Result.as_maps(any()),
        return: [
          %{"age" => 78, "name" => "Alex Trebek"},
          %{"age" => 72, "name" => "Pat Sajak"},
          %{"age" => nil, "name" => "Wayne Brady"}
        ]
      )

      last_insert_key = "forklift:last_insert_date:#{dataset.id}"
      completeness_key = "#{@completeness_key}:#{dataset.id}"

      stats = %{
        id: dataset.id,
        total_score: 0.8333333333333334,
        record_count: 3,
        fields: %{
          "name" => %{count: 3, required: false},
          "age" => %{count: 2, required: false}
        }
      }

      {:ok, %{dataset: dataset, last_insert_key: last_insert_key, completeness_key: completeness_key, stats: stats}}
    end

    test "Writes stats to redis for non-remote datasets", %{
      dataset: dataset,
      last_insert_key: last_insert_key,
      completeness_key: completeness_key,
      stats: stats
    } do
      allow(Persistence.get(last_insert_key), return: "2019-06-05T14:01:36.466729Z")
      allow(Persistence.get(completeness_key), return: "2019-06-05T13:59:09.630290Z")
      StatsCalculator.produce_completeness_stats()

      assert_called(Persistence.persist("discovery-api:stats:#{dataset.id}", stats))
      assert_called(Persistence.persist("#{@completeness_key}:#{dataset.id}", any()))
    end

    test "Writes stats to redis when data has loaded, but no stats have been calculated", %{
      dataset: dataset,
      last_insert_key: last_insert_key,
      completeness_key: completeness_key,
      stats: stats
    } do
      allow(Persistence.get(last_insert_key), return: "2019-06-05T14:01:36.466729Z")
      allow(Persistence.get(completeness_key), return: "2019-06-05T13:59:09.630290Z")

      StatsCalculator.produce_completeness_stats()

      assert_called(Persistence.persist("discovery-api:stats:#{dataset.id}", stats))
      assert_called(Persistence.persist("#{@completeness_key}:#{dataset.id}", any()))
    end
  end

  describe "produce_completeness_stats/1 negative cases" do
    test "Does not calculate statistics for remote datasets" do
      allow(RaptorService.list_access_groups_by_dataset(any(), any()), return: %{access_groups: []})
      dataset = mock_remote_dataset()
      allow(Model.get_all(), return: [dataset], meck_options: [:passthrough])
      allow(Persistence.persist(any(), any()), return: :does_not_matter)

      allow(Prestige.query!(any(), any()),
        return: []
      )

      StatsCalculator.produce_completeness_stats()

      refute_called(Persistence.persist("discovery-api:stats:#{dataset.id}", any()))

      refute_called(Persistence.persist("#{@completeness_key}:#{dataset.id}", any()))
    end

    test "Does not calculate statistics for datasets that have not been updated since last calculation date" do
      allow(RaptorService.list_access_groups_by_dataset(any(), any()), return: %{access_groups: []})
      dataset = mock_non_remote_dataset()
      allow(Model.get_all(), return: [dataset], meck_options: [:passthrough])
      allow(Persistence.persist(any(), any()), return: :does_not_matter)

      allow(Prestige.query!(any(), any()),
        return: [
          %{"age" => 78, "name" => "Alex Trebek"},
          %{"age" => 72, "name" => "Pat Sajak"},
          %{"age" => nil, "name" => "Wayne Brady"}
        ]
      )

      last_inserted_key = "forklift:last_insert_date:#{dataset.id}"
      complete_key = "#{@completeness_key}:#{dataset.id}"
      allow(Persistence.get(last_inserted_key), return: "2019-06-05T13:59:09.630290Z")
      allow(Persistence.get(complete_key), return: "2019-06-05T14:01:36.466729Z")

      StatsCalculator.produce_completeness_stats()

      refute_called(Persistence.persist("discovery-api:stats:#{dataset.id}", any()))

      refute_called(Persistence.persist("#{@completeness_key}:#{dataset.id}", any()))
    end

    test "Does not calculate statistics when presto returns no data" do
      allow(RaptorService.list_access_groups_by_dataset(any(), any()), return: %{access_groups: []})
      dataset = mock_non_remote_dataset()
      allow(Model.get_all(), return: [dataset], meck_options: [:passthrough])

      allow(Persistence.persist(any(), any()), return: :does_not_matter)
      allow(Prestige.query!(any(), any()), return: [])

      allow(Persistence.get(any()), return: nil)

      StatsCalculator.produce_completeness_stats()

      refute_called(
        Persistence.persist(
          "discovery-api:stats:#{dataset.id}",
          %{id: dataset.id}
        )
      )

      refute_called(Persistence.persist("#{@completeness_key}:#{dataset.id}", any()))
    end
  end

  defp mock_non_remote_dataset() do
    {:ok, data_model} =
      TDG.create_dataset(%{
        id: @dataset_id,
        technical: %{
          sourceType: "ingest",
          sourceFormat: "gtfs",
          schema: [
            %{name: "name", required: false, type: "string"},
            %{name: "age", required: false, type: "int"}
          ]
        }
      })
      |> Mapper.to_data_model(@organization)

    data_model
  end

  defp mock_remote_dataset() do
    {:ok, data_model} =
      TDG.create_dataset(
        id: @dataset_id,
        technical: %{
          sourceType: "remote",
          sourceFormat: "gtfs"
        }
      )
      |> Mapper.to_data_model(@organization)

    data_model
  end
end
