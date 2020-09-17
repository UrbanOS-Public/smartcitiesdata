defmodule Forklift.Jobs.JsonToOrcTest do
  use ExUnit.Case

  alias Forklift.Jobs.JsonToOrc
  alias SmartCity.TestDataGenerator, as: TDG
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias Pipeline.Writer.TableWriter.Statement
  alias Pipeline.Writer.S3Writer
  alias SmartCity.TestDataGenerator.Payload
  import SmartCity.TestHelper

  use Divo

  import SmartCity.Event,
  only: [
    dataset_update: 0,
    data_ingest_start: 0
  ]

  @instance Forklift.instance_name()
  @bucket Application.get_env(:forklift, :s3_writer_bucket)

  setup do
    datasets =
      [1, 2]
    |> Enum.map(fn _ -> TDG.create_dataset(%{technical: %{cadence: "once"}}) end)
    |> Enum.map(fn dataset ->
      Brook.Event.send(@instance, dataset_update(), :forklift, dataset)
      Brook.Event.send(@instance, data_ingest_start(), :forklift, dataset)
      dataset
    end)

    # Wait for tables to be created
    eventually(fn ->
      assert Enum.all?(datasets, fn dataset -> table_exists?(dataset.technical.systemName) end)
    end,
    100,
    1_000)

    # Delete original tables
    Enum.each(datasets, fn dataset -> drop_table(dataset.technical.systemName) end)

    # Recreate orc tables from partitioned tables
    Enum.each(datasets, fn dataset -> create_partitioned_table(dataset.technical.systemName) end)

    # Wait for tables to be created
    eventually(fn ->
      assert Enum.all?(datasets, fn dataset -> table_exists?(dataset.technical.systemName) end)
    end,
    100,
    1_000)

    [datasets: datasets]
  end

  test "should do a thing for each provided dataset id", %{datasets: datasets} do
    expected_records = 10
    Enum.each(datasets, fn dataset -> write_records(dataset, expected_records) end)

    # Run Job
    dataset_ids = Enum.map(datasets, fn dataset -> dataset.id end)
    JsonToOrc.run(dataset_ids)

    # Validate data is in orc table with os_partition
    assert Enum.all?(datasets, fn dataset -> count(dataset.technical.systemName) == expected_records end)

    table = List.first(datasets) |> Map.get(:technical) |> Map.get(:systemName)
    {:ok, response} = PrestigeHelper.execute_query("select * from #{table}")
    actual_partition = response |> Prestige.Result.as_maps() |> List.first() |> Map.get("os_partition")
    assert {:ok, _} = Timex.parse(actual_partition, "{YYYY}_{0M}")

    # Validate data is no longer in json table
    assert Enum.all?(datasets, fn dataset -> count(dataset.technical.systemName <> "__json") == 0 end)

  end

  defp table_exists?(table) do
    case PrestigeHelper.execute_query("show create table #{table}") do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp drop_table(table) do
    %{table: table}
    |> Statement.drop()
    |> PrestigeHelper.execute_query()
  end

  defp create_partitioned_table(table) do
    # "create table jalson_test with (partitioned_by = ARRAY['os_partition'], format = 'ORC') as (select *, date_format(from_iso8601_timestamp(timestamp), '%Y_%m') as os_partition from us33_smart_corridor__marysville_bsm limit 100);"
    "create table #{table} with (partitioned_by = ARRAY['os_partition'], format = 'ORC') as (select *, cast('2020-09' as varchar) as os_partition from #{table}__json) limit 0"
    |> PrestigeHelper.execute_query()
  end

  defp write_records(dataset, count) do
    data = 1..count |> Enum.map(fn _ -> TDG.create_data(%{payload: payload()}) end)
    S3Writer.write(data, [bucket: @bucket, table: dataset.technical.systemName, schema: dataset.technical.schema])
  end

  defp payload() do
    %{
      "my_int" => 1,
      "my_string" => "Bob",
      "my_date" => Timex.format!(DateTime.utc_now(), "{ISO:Extended:Z}"),
      "my_float" => 1.5,
      "my_boolean" => "true"
    }
  end

  defp count(table) do
    case PrestigeHelper.execute_query("select count(1) from #{table}") do
      {:ok, new_results} ->
        [[new_row_count]] = new_results.rows
        new_row_count

      _ ->
        :error
    end
  end

  # ensure ingestion is turned off while running
end
