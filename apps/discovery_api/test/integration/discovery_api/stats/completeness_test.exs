defmodule DiscoveryApi.Stats.CompletenessTest do
  use ExUnit.Case
  use Divo
  use DiscoveryApi.DataCase
  alias SmartCity.Registry.Dataset
  import SmartCity.TestHelper
  alias DiscoveryApi.TestDataGenerator, as: TDG
  alias DiscoveryApi.Data.Persistence
  alias DiscoveryApi.Stats.StatsCalculator
  alias DiscoveryApi.Stats.DataHelper
  alias DiscoveryApi.Test.Helper

  setup do
    Helper.wait_for_brook_to_be_ready()
    Redix.command!(:redix, ["FLUSHALL"])
    :ok
  end

  @moduletag capture_log: true
  describe "produce_completeness_stats/0" do
    test "Adds stats entries for dataset to redis" do
      organization = Helper.create_persisted_organization()

      dataset1 =
        TDG.create_dataset(%{
          technical: %{
            orgId: organization.id,
            private: false,
            systemName: "test_table",
            schema: DataHelper.real_dataset_schema()
          }
        })

      dataset2 =
        TDG.create_dataset(%{
          technical: %{
            orgId: organization.id,
            private: false,
            systemName: "test_table2",
            schema: [
              %{name: "name", type: "varchar", required: false},
              %{name: "age", type: "int", required: false}
            ]
          }
        })

      Dataset.write(dataset1)
      Dataset.write(dataset2)

      dataset1
      |> PrestoTestHelper.create_test_table()
      |> Prestige.execute()
      |> Prestige.prefetch()

      dataset1
      |> PrestoTestHelper.insert_sample_data()
      |> Prestige.execute()
      |> Prestige.prefetch()

      Persistence.persist("forklift:last_insert_date:#{dataset1.id}", DateTime.utc_now())

      dataset2
      |> PrestoTestHelper.create_small_test_table()
      |> Prestige.execute()
      |> Prestige.prefetch()

      dataset2
      |> PrestoTestHelper.insert_small_sample_data()
      |> Prestige.execute()
      |> Prestige.prefetch()

      Persistence.persist("forklift:last_insert_date:#{dataset2.id}", DateTime.utc_now())

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
        "total_score" => 0.9,
        "record_count" => 7343
      }

      expected_dataset2_column_stats = %{
        "id" => dataset2.id,
        "fields" => %{
          "name" => %{"count" => 3, "required" => false},
          "age" => %{"count" => 2, "required" => false}
        },
        "total_score" => 0.8333333333333334,
        "record_count" => 3
      }

      StatsCalculator.produce_completeness_stats()

      eventually(
        fn -> assert get_column_stats_from_redis(dataset1.id) == expected_dataset1_column_stats end,
        dwell: 2000,
        max_tries: 10
      )

      eventually(fn ->
        assert Map.get(
                 get_dataset_completeness_from_details_endpoint(dataset1.id),
                 "total_score",
                 nil
               ) ==
                 expected_dataset1_column_stats["total_score"]
      end)

      eventually(
        fn ->
          assert get_dataset_completeness_from_stats_endpoint(dataset1.id) ==
                   expected_dataset1_column_stats
        end,
        dwell: 2000,
        max_tries: 10
      )

      eventually(
        fn -> assert get_column_stats_from_redis(dataset2.id) == expected_dataset2_column_stats end,
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

  defp get_dataset_completeness_from_details_endpoint(dataset_id) do
    "http://localhost:4000/api/v1/dataset/#{dataset_id}"
    |> HTTPoison.get!()
    |> Map.from_struct()
    |> Map.get(:body)
    |> Jason.decode!()
    |> Map.get("completeness", %{})
  end

  defp get_dataset_completeness_from_stats_endpoint(dataset_id) do
    "http://localhost:4000/api/v1/dataset/#{dataset_id}/stats"
    |> HTTPoison.get!()
    |> Map.from_struct()
    |> Map.get(:body)
    |> Jason.decode!()
  end
end
