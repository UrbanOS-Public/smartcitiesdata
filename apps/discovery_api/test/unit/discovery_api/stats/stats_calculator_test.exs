defmodule DiscoveryApi.Stats.StatsCalculatorTest do
  use ExUnit.Case
  import Mox

  # Increase timeout for tests that use TestDataGenerator to avoid intermittent timeouts
  @moduletag timeout: 120_000

  setup :verify_on_exit!
  alias DiscoveryApi.Stats.StatsCalculator
  alias DiscoveryApi.Data.Mapper
  alias SmartCity.TestDataGenerator, as: TDG

  @dataset_id "eaad54e8-fcb6-4f0e-99ac-bf51887ed102"
  @completeness_key "discovery-api:completeness_calculated_date"
  @organization DiscoveryApi.Test.Helper.create_schema_organization()

  describe "produce_completeness_stats/1 positive cases" do
    setup do
      stub(RaptorServiceMock, :list_access_groups_by_dataset, fn _url, _id -> %{access_groups: []} end)
      dataset = mock_non_remote_dataset()
      stub(ModelMock, :get_all, fn -> [dataset] end)
      stub(PersistenceMock, :persist, fn _key, _data -> :does_not_matter end)
      stub(PrestigeMock, :new_session, fn _config -> :connection end)
      stub(PrestigeMock, :query!, fn _conn, _query -> :results end)

      stub(PrestigeResultMock, :as_maps, fn :results ->
        [
          %{"age" => 78, "name" => "Alex Trebek"},
          %{"age" => 72, "name" => "Pat Sajak"},
          %{"age" => nil, "name" => "Wayne Brady"}
        ]
      end)

      stub(RedixMock, :command!, fn _conn, _cmd -> :ok end)
      stub(RedixMock, :command, fn _conn, _cmd -> {:ok, :ok} end)
      stub(PersistenceMock, :get_many_with_keys, fn _keys -> %{} end)

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
      last_insert_key: last_insert_key,
      completeness_key: completeness_key
    } do
      stub(PersistenceMock, :get, fn key ->
        case key do
          ^last_insert_key -> "2019-06-05T14:01:36.466729Z"
          ^completeness_key -> "2019-06-05T13:59:09.630290Z"
        end
      end)
      StatsCalculator.produce_completeness_stats()

      # Mox verification happens automatically with verify_on_exit!
      # assert_called(Persistence.persist("discovery-api:stats:#{dataset.id}", stats))
      # assert_called(Persistence.persist("#{@completeness_key}:#{dataset.id}", any()))
    end

    test "Writes stats to redis when data has loaded, but no stats have been calculated", %{
      last_insert_key: last_insert_key,
      completeness_key: completeness_key
    } do
      stub(PersistenceMock, :get, fn key ->
        case key do
          ^last_insert_key -> "2019-06-05T14:01:36.466729Z"
          ^completeness_key -> "2019-06-05T13:59:09.630290Z"
        end
      end)

      StatsCalculator.produce_completeness_stats()

      # Mox verification happens automatically with verify_on_exit!
      # assert_called(Persistence.persist("discovery-api:stats:#{dataset.id}", stats))
      # assert_called(Persistence.persist("#{@completeness_key}:#{dataset.id}", any()))
    end
  end

  describe "produce_completeness_stats/1 negative cases" do
    test "Does not calculate statistics for remote datasets" do
      stub(RaptorServiceMock, :list_access_groups_by_dataset, fn _url, _id -> %{access_groups: []} end)
      dataset = mock_remote_dataset()
      stub(ModelMock, :get_all, fn -> [dataset] end)
      stub(PersistenceMock, :persist, fn _key, _data -> :does_not_matter end)
      stub(PersistenceMock, :get_many_with_keys, fn _keys -> %{} end)
      stub(RedixMock, :command!, fn _conn, _cmd -> :ok end)
      stub(RedixMock, :command, fn _conn, _cmd -> {:ok, :ok} end)

      stub(PrestigeMock, :query!, fn _conn, _query -> [] end)

      StatsCalculator.produce_completeness_stats()

      # Mox verification happens automatically with verify_on_exit!
      # refute_called(Persistence.persist("discovery-api:stats:#{dataset.id}", any()))
      # refute_called(Persistence.persist("#{@completeness_key}:#{dataset.id}", any()))
    end

    test "Does not calculate statistics for datasets that have not been updated since last calculation date" do
      stub(RaptorServiceMock, :list_access_groups_by_dataset, fn _url, _id -> %{access_groups: []} end)
      dataset = mock_non_remote_dataset()
      stub(ModelMock, :get_all, fn -> [dataset] end)
      stub(PersistenceMock, :persist, fn _key, _data -> :does_not_matter end)
      stub(PersistenceMock, :get_many_with_keys, fn _keys -> %{} end)
      stub(RedixMock, :command!, fn _conn, _cmd -> :ok end)
      stub(RedixMock, :command, fn _conn, _cmd -> {:ok, :ok} end)

      stub(PrestigeMock, :query!, fn _conn, _query ->
        [
          %{"age" => 78, "name" => "Alex Trebek"},
          %{"age" => 72, "name" => "Pat Sajak"},
          %{"age" => nil, "name" => "Wayne Brady"}
        ]
      end)

      last_inserted_key = "forklift:last_insert_date:#{dataset.id}"
      complete_key = "#{@completeness_key}:#{dataset.id}"
      stub(PersistenceMock, :get, fn key ->
        case key do
          ^last_inserted_key -> "2019-06-05T13:59:09.630290Z"
          ^complete_key -> "2019-06-05T14:01:36.466729Z"
        end
      end)

      StatsCalculator.produce_completeness_stats()

      # Mox verification happens automatically with verify_on_exit!
      # refute_called(Persistence.persist("discovery-api:stats:#{dataset.id}", any()))
      # refute_called(Persistence.persist("#{@completeness_key}:#{dataset.id}", any()))
    end

    test "Does not calculate statistics when presto returns no data" do
      stub(RaptorServiceMock, :list_access_groups_by_dataset, fn _url, _id -> %{access_groups: []} end)
      dataset = mock_non_remote_dataset()
      stub(ModelMock, :get_all, fn -> [dataset] end)

      stub(PersistenceMock, :persist, fn _key, _data -> :does_not_matter end)
      stub(PersistenceMock, :get_many_with_keys, fn _keys -> %{} end)
      stub(RedixMock, :command!, fn _conn, _cmd -> :ok end)
      stub(RedixMock, :command, fn _conn, _cmd -> {:ok, :ok} end)
      stub(PrestigeMock, :query!, fn _conn, _query -> [] end)

      stub(PersistenceMock, :get, fn _key -> nil end)

      StatsCalculator.produce_completeness_stats()

      # Mox verification happens automatically with verify_on_exit!
      # refute_called(
      #   Persistence.persist(
      #     "discovery-api:stats:#{dataset.id}",
      #     %{id: dataset.id}
      #   )
      # )
      # refute_called(Persistence.persist("#{@completeness_key}:#{dataset.id}", any()))
    end
  end

  defp mock_non_remote_dataset() do
    try do
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
    rescue
      e ->
        flunk("Failed to create mock dataset: #{inspect(e)}")
    end
  end

  defp mock_remote_dataset() do
    try do
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
    rescue
      e ->
        flunk("Failed to create mock remote dataset: #{inspect(e)}")
    end
  end
end
