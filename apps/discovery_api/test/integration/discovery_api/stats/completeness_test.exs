defmodule DiscoveryApi.Stats.CompletenessTest do
  import ExUnit.CaptureLog
  use ExUnit.Case
  use Divo
  alias SmartCity.{Dataset, Organization}
  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.Stats.StatsCalculator
  alias DiscoveryApi.Stats.DataHelper

  setup do
    Redix.command!(:redix, ["FLUSHALL"])
    :ok
  end

  @moduletag capture_log: true
  describe "produce_completeness_stats/0" do
    test "Adds stats entries for dataset to redis" do
      organization = TDG.create_organization(%{})
      Organization.write(organization)

      dataset1 =
        TDG.create_dataset(%{
          technical: %{
            orgId: organization.id,
            private: true,
            systemName: "test_table",
            schema: DataHelper.real_dataset_schema()
          }
        })

      dataset2 =
        TDG.create_dataset(%{
          technical: %{
            orgId: organization.id,
            private: true,
            systemName: "test_table2",
            schema: [
              %{name: "name", type: "varchar", required: false},
              %{name: "age", type: "int", required: false}
            ]
          }
        })

      Dataset.write(dataset1)
      Dataset.write(dataset2)

      PrestoTestHelper.create_test_table()
      |> Prestige.execute()
      |> Prestige.prefetch()

      PrestoTestHelper.insert_sample_data()
      |> Prestige.execute()
      |> Prestige.prefetch()

      PrestoTestHelper.create_small_test_table()
      |> Prestige.execute()
      |> Prestige.prefetch()

      PrestoTestHelper.insert_small_sample_data()
      |> Prestige.execute()
      |> Prestige.prefetch()

      expected_dataset1_column_stats = %{
        "id" => dataset1.id,
        "fields" => %{
          "bikes_allowed" => %{"count" => 7343, "required" => false},
          "block_id" => %{"count" => 7343, "required" => false},
          "direction_id" => %{"count" => 7343, "required" => false},
          "route_id" => %{"count" => 7343, "required" => false},
          "service_id" => %{"count" => 7343, "required" => false},
          "shape_id" => %{"count" => 7343, "required" => false},
          "trip_headsign" => %{"count" => 7343, "required" => false},
          "trip_id" => %{"count" => 7343, "required" => false},
          "trip_short_name" => %{"count" => 0, "required" => false},
          "wheelchair_accessible" => %{"count" => 7343, "required" => false}
        },
        "completeness" => 0.9,
        "record_count" => 7343
      }

      expected_dataset2_column_stats = %{
        "id" => dataset2.id,
        "fields" => %{
          "name" => %{"count" => 3, "required" => false},
          "age" => %{"count" => 2, "required" => false}
        },
        "completeness" => 0.8333333333333334,
        "record_count" => 3
      }

      StatsCalculator.produce_completeness_stats()

      Patiently.wait_for!(
        fn -> get_column_stats_from_redis(dataset1.id) == expected_dataset1_column_stats end,
        dwell: 2000,
        max_tries: 10
      )

      Patiently.wait_for!(
        fn -> get_column_stats_from_redis(dataset2.id) == expected_dataset2_column_stats end,
        dwell: 2000,
        max_tries: 10
      )
    end
  end

  defp get_column_stats_from_redis(dataset_id) do
    stats_key = "discovery-api:stats:#{dataset_id}"

    case Redix.command!(:redix, ["GET", stats_key]) do
      nil -> nil
      entry -> Jason.decode!(entry)
    end
  end
end
