defmodule Forklift.Performance.CompactionTest do
  use ExUnit.Case
  use Divo, auto_start: false
  use Retry
  use Properties, otp_app: :forklift

  require Logger

  alias SmartCity.TestDataGenerator, as: TDG
  alias ExAws.S3
  import SmartCity.TestHelper, only: [eventually: 3]

  @moduletag :compaction

  getter(:s3_writer_bucket, generic: true)

  setup_all do
    Mix.Task.run("loadconfig", ["./config/performance.exs"])
    Application.ensure_all_started(:forklift)
    large_source = sync_fixtures_to_local_path("compaction-test-fixtures/cota")
    medium_source = sync_fixtures_to_local_path("compaction-test-fixtures/ips")

    [
      large_source: large_source,
      medium_source: medium_source
    ]
  end

  @tag timeout: :infinity
  test "large compactions don't intermittently fail", %{large_source: source} do
    Logger.configure(level: :info)
    scale = 2

    source_dataset = dataset_from_source(source)
    source_table_name = source_dataset.technical.systemName
    dataset = TDG.create_dataset(%{technical: %{schema: source_dataset.technical.schema}})

    log("creating dataset #{dataset.id} as a copy of #{source_table_name} * #{to_string(scale)}")

    log("creating table for #{dataset.id}")
    assert :ok == create_table(dataset)

    log("loading source data into table for #{dataset.id}")
    load_data_from_source(dataset, source, scale)

    log("getting record counts from table for #{dataset.id}")
    {json_count, orc_count} = get_record_counts(dataset)
    expected_orc_count = orc_count + json_count
    expected_json_count = 0

    log(
      "expect there to be #{expected_orc_count} orc records and #{expected_json_count} json records for #{dataset.id}"
    )

    log("running compaction for #{dataset.id}")
    assert :ok == compact(dataset)

    log("confirming record counts from table for #{dataset.id}")
    assert {^expected_json_count, ^expected_orc_count} = get_record_counts(dataset)

    log("dropping tables for successful compaction #{dataset.id}")
    drop_tables(dataset)
  end

  @tag timeout: :infinity
  test "large compactions don't wipe data if they are stopped after dropping orc table", %{large_source: source} do
    Logger.configure(level: :info)
    scale = 1

    source_dataset = dataset_from_source(source)
    source_table_name = source_dataset.technical.systemName
    dataset = TDG.create_dataset(%{technical: %{schema: source_dataset.technical.schema}})

    log("creating dataset #{dataset.id} as a copy of #{source_table_name} * #{to_string(scale)}")

    log("creating table for #{dataset.id}")
    assert :ok == create_table(dataset)

    log("loading source data into table for #{dataset.id}")
    load_data_from_source(dataset, source, scale)

    log("getting record counts from table for #{dataset.id}")
    {json_count, orc_count} = get_record_counts(dataset)
    expected_orc_count = orc_count + json_count

    log("running compaction for #{dataset.id} in background")
    compaction_task = Task.async(fn -> compact(dataset) end)

    log("waiting for orc table to disappear")
    orc_table = orc_table_name(dataset)

    eventually(
      fn ->
        assert table_exists?(orc_table) != true
      end,
      500,
      3_000
    )

    log("stopping compaction task with no shutdown timeout")
    Task.shutdown(compaction_task, :brutal_kill)

    log("confirming compaction table record counts from table for #{dataset.id}")
    compact_table = compact_table_name(dataset)
    assert expected_orc_count == get_record_count_for_table(compact_table)

    log("running a subsequent compaction for #{dataset.id}")
    # compaction will not run with 0 records in JSON table
    load_data_from_source(dataset, source, scale, ["json"])
    json_table = json_table_name(dataset)
    assert json_count == get_record_count_for_table(json_table)
    assert :ok == compact(dataset)

    log("confirming that no data is lost, assuming we get back to just ORC + JSON tables")
    assert expected_orc_count + json_count == get_record_count_for_table(orc_table)
    assert 0 == get_record_count_for_table(json_table)
    assert table_exists?(orc_table)
  end

  defp dataset_from_source(source) do
    {:ok, dataset} =
      (source <> "/dataset.json")
      |> File.read!()
      |> SmartCity.Dataset.new()

    dataset
  end

  @type_suffix_mapping %{
    "json" => "__json/",
    "orc" => "/"
  }
  defp load_data_from_source(dataset, source, scale, types \\ ["orc", "json"]) do
    base_table_name = String.downcase(dataset.technical.systemName)

    Enum.each(types, fn type ->
      path = source <> "/" <> type
      table_name = base_table_name <> @type_suffix_mapping[type]

      Enum.each(Range.new(1, scale), fn iteration ->
        load_files_to_s3(path, table_name, iteration)
      end)
    end)
  end

  defp load_files_to_s3(path, table_name, iteration) do
    Enum.each(File.ls!(path), fn file ->
      source = path <> "/" <> file
      destination = "/hive-s3/" <> table_name <> to_string(iteration) <> "_" <> file

      load_file_to_s3(source, destination)
    end)
  end

  defp load_file_to_s3(source_path, destination_path) do
    source_path
    |> S3.Upload.stream_file()
    |> S3.upload(s3_writer_bucket(), destination_path)
    |> ExAws.request!()
  end

  defp create_table(dataset) do
    table = dataset.technical.systemName
    schema = dataset.technical.schema

    Forklift.DataWriter.init(table: table, schema: schema, bucket: s3_writer_bucket())
  end

  defp drop_tables(dataset) do
    main_table = orc_table_name(dataset)
    json_table = json_table_name(dataset)

    prestige_execute("drop table #{main_table}")
    prestige_execute("drop table #{json_table}")
  end

  defp get_record_counts(dataset) do
    main_table = orc_table_name(dataset)
    json_table = json_table_name(dataset)

    orc_count = get_record_count_for_table(main_table)
    json_count = get_record_count_for_table(json_table)

    {json_count, orc_count}
  end

  defp get_record_count_for_table(name) do
    prestige_execute("select count(1) from #{name}")
    |> extract_count()
  end

  defp extract_count({:ok, %{rows: [[count]]}}), do: count

  defp prestige_execute(statement) do
    prestige_opts()
    |> Prestige.new_session()
    |> Prestige.execute(statement)
  end

  defp compact(dataset) do
    Forklift.DataWriter.compact_dataset(dataset)
  end

  def prestige_opts() do
    Application.get_env(:prestige, :session_opts)
  end

  def sync_fixtures_to_local_path(common_path) do
    local_path = "./test/integration/performance/#{common_path}"

    case File.dir?(local_path) do
      true ->
        log("fixtures already available locally at #{local_path}")

      false ->
        remote_bucket = "scos-source-datasets"
        remote_path = common_path
        log("downloading fixtures from #{remote_bucket}/#{remote_path} to #{local_path}")
        keys_to_download = list_keys_with_prefix(remote_bucket, remote_path)
        download_keys(keys_to_download, remote_bucket, remote_path, local_path)
    end

    local_path
  end

  defp list_keys_with_prefix(bucket, prefix) do
    ExAws.S3.list_objects(bucket, prefix: prefix)
    |> ExAws.request!(remote_config())
    |> get_in([:body, :contents])
    |> Enum.map(&Map.get(&1, :key))
  end

  defp download_keys(keys, bucket, remote_path, local_path) do
    File.mkdir_p!(local_path)
    File.mkdir_p!(local_path <> "/orc")
    File.mkdir_p!(local_path <> "/json")

    Enum.each(keys, fn key ->
      file_name = String.replace(key, remote_path, "")
      log("downloading #{local_path}#{file_name} from #{bucket}/#{key}")

      ExAws.S3.download_file(bucket, key, local_path <> file_name)
      |> ExAws.request!(remote_config())
    end)
  end

  defp remote_config() do
    aws_profile = System.get_env("AWS_PROFILE")

    unless aws_profile do
      raise "you need to have AWS_PROFILE set to a profile that can access ALM to sync the fixtures to your local environment"
    end

    config =
      Map.merge(
        ExAws.Config.Defaults.get(:s3, "us-west-2"),
        %{
          access_key_id: [{:awscli, aws_profile, 30}, :instance_role],
          secret_access_key: [{:awscli, aws_profile, 30}, :instance_role],
          region: "us-west-2"
        }
      )

    ExAws.Config.new(:s3, config)
  end

  defp orc_table_name(dataset) do
    String.downcase(dataset.technical.systemName)
  end

  defp json_table_name(dataset) do
    orc_table_name(dataset) <> "__json"
  end

  defp compact_table_name(dataset) do
    orc_table_name(dataset) <> "_compact"
  end

  defp table_exists?(table) do
    case prestige_execute("show create table #{table}") do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp log(message) do
    Logger.info("CompactionTest: " <> message)
  end
end
