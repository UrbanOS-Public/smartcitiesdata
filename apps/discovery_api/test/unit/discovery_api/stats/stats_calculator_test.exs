defmodule DiscoveryApi.Stats.StatsCalculatorTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Stats.CompletenessTotals
  alias SmartCity.{Dataset, Organization}
  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.Stats.StatsCalculator
  alias DiscoveryApi.Stats.DataHelper
  alias DiscoveryApi.Data.Persistence

  @dataset_id "eaad54e8-fcb6-4f0e-99ac-bf51887ed102"

  describe "produce_completeness_stats/1" do
    test "Writes stats data to redis for non-remote datasets" do
      allow(Dataset.get_all!(), return: mock_non_remote_dataset, meck_options: [:passthrough])
      allow(Persistence.persist(any(), any()), return: :does_not_matter)

      allow(Prestige.execute(any(), any()),
        return: [
          %{"age" => 78, "name" => "Alex Trebek"},
          %{"age" => 72, "name" => "Pat Sajak"},
          %{"age" => nil, "name" => "Wayne Brady"}
        ]
      )

      StatsCalculator.produce_completeness_stats()

      assert_called(
        Persistence.persist(
          "discovery-api:stats:#{@dataset_id}",
          %{
            id: @dataset_id,
            completeness: 0.8333333333333334,
            record_count: 3,
            fields: %{
              "name" => %{count: 3, required: false},
              "age" => %{count: 2, required: false}
            }
          }
        )
      )
    end

    test "Does not calculate statistics for remote datasets" do
      allow(Dataset.get_all!(), return: mock_remote_dataset, meck_options: [:passthrough])
      allow(Persistence.persist(any(), any()), return: :does_not_matter)

      allow(Prestige.execute(any(), any()),
        return: []
      )

      StatsCalculator.produce_completeness_stats()

      refute_called(Prestige.execute(any(), any()))
    end

    test "Works when presto returns no data" do
      allow(Dataset.get_all!(), return: mock_non_remote_dataset, meck_options: [:passthrough])

      allow(Persistence.persist(any(), any()), return: :does_not_matter)
      allow(Prestige.execute(any(), any()), return: [])

      StatsCalculator.produce_completeness_stats()

      assert_called(
        Persistence.persist(
          "discovery-api:stats:#{@dataset_id}",
          %{id: @dataset_id}
        )
      )
    end
  end

  def mock_non_remote_dataset() do
    [
      %SmartCity.Dataset{
        _metadata: %SmartCity.Dataset.Metadata{expectedBenefit: [], intendedUse: []},
        business: nil,
        id: @dataset_id,
        technical: %SmartCity.Dataset.Technical{
          cadence: 4654,
          dataName: "Tawny_Laranja",
          headers: %{accepts: "application/json"},
          orgId: "orgId",
          orgName: "Rosa_Jasper",
          partitioner: %{query: nil, type: nil},
          private: true,
          queryParams: %{apiKey: "d3b0afb2-66bc-496f-8b0c-32c6872f1515"},
          schema: [
            %{name: "name", required: false, type: "string"},
            %{name: "age", required: false, type: "int"}
          ],
          sourceFormat: "gtfs",
          sourceType: "batch",
          sourceUrl: "schultz.org",
          systemName: "test_table",
          transformations: ["trim", "aggregate", "rename_field"],
          validations: ["matches_schema", "no_nulls"]
        },
        version: "0.2"
      }
    ]
  end

  def mock_remote_dataset() do
    [
      %SmartCity.Dataset{
        _metadata: %SmartCity.Dataset.Metadata{expectedBenefit: [], intendedUse: []},
        business: nil,
        id: @dataset_id,
        technical: %SmartCity.Dataset.Technical{
          private: true,
          queryParams: %{apiKey: "d3b0afb2-66bc-496f-8b0c-32c6872f1515"},
          schema: [
            %{name: "name", required: false, type: "string"},
            %{name: "age", required: false, type: "int"}
          ],
          sourceFormat: "gtfs",
          sourceType: "remote",
          sourceUrl: "schultz.org",
          systemName: "test_table"
        },
        version: "0.2"
      }
    ]
  end
end
