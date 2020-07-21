defmodule Forklift.Performance.CompactionTest do
  use ExUnit.Case
  # use Divo
  use Retry
  require Logger

  alias SmartCity.TestDataGenerator, as: TDG
  alias ExAws.S3

  @moduletag :performance

  @bucket Application.get_env(:forklift, :s3_writer_bucket)

  setup_all do
    Mix.Task.run("loadconfig", ["./config/performance.exs"])
    Logger.configure(level: :debug)
    Application.ensure_all_started(:forklift)

    :ok
  end

  @tag timeout: :infinity
  test "run compaction test" do
    source = sync_fixtures_to_local_path("compaction-test-fixtures/cota")
    scale = 1

    source_dataset = dataset_from_source(source)
    dataset = TDG.create_dataset(%{technical: %{schema: source_dataset.technical.schema}})

    Logger.debug("creating dataset #{dataset.id} as a copy of #{dataset.technical.systemName}")
    Logger.debug("creating table for #{dataset.id}")
    assert :ok == create_table(dataset)

    Logger.debug("loading source data into table for #{dataset.id}")
    load_data_from_source(dataset, source, scale)

    Logger.debug("getting record counts from table for #{dataset.id}")
    {json_count, orc_count} = get_record_counts(dataset)
    expected_orc_count = orc_count + json_count
    expected_json_count = 0
    Logger.debug("expect there to be #{expected_orc_count} orc records and #{expected_json_count} json records when compaction completes for #{dataset.id}")

    Logger.debug("running compaction for #{dataset.id}")
    assert :ok = compact(dataset)

    Logger.debug("confirming record counts from table for #{dataset.id}")
    assert {^expected_orc_count, ^expected_json_count} = get_record_counts(dataset)

    Logger.debug("dropping tables for successful compaction #{dataset.id}")
    drop_tables(dataset)
  end

  defp dataset_from_source(source) do
    {:ok, dataset} = source <> "/dataset.json"
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
    |> S3.upload(@bucket, destination_path)
    |> ExAws.request!()
  end

  defp create_table(dataset) do
    table = dataset.technical.systemName
    schema = dataset.technical.schema

    Forklift.DataWriter.init([table: table, schema: schema, bucket: @bucket])
  end

  defp drop_tables(dataset) do
    main_table = dataset.technical.systemName
    json_table = main_table <> "__json"

    prestige_execute("drop table #{main_table}")
    prestige_execute("drop table #{json_table}")
  end

  defp get_record_counts(dataset) do
    main_table = dataset.technical.systemName
    json_table = main_table <> "__json"

    orc_count = prestige_execute("select count(1) from #{main_table}")
    |> extract_count()

    json_count = prestige_execute("select count(1) from #{json_table}")
    |> extract_count()

    {orc_count, json_count}
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
        Logger.debug("fixtures already available locally at #{local_path}")
      false ->
        remote_bucket = "presto-hive-storage-dev"
        remote_path = common_path
        Logger.debug("downloading fixtures from #{remote_bucket}/#{remote_path} to #{local_path}")
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
      ExAws.S3.download_file(bucket, key, local_path <> file_name)
      |> ExAws.request!(remote_config())
    end)
  end

  defp remote_config() do
    aws_profile = System.get_env("AWS_PROFILE")
    config = Map.merge(
      ExAws.Config.Defaults.get(:s3, "us-west-2"),
      %{
        access_key_id: [{:awscli, aws_profile, 30}, :instance_role],
        secret_access_key: [{:awscli, aws_profile, 30}, :instance_role],
        region: "us-west-2"
      }
    )

    ExAws.Config.new(:s3, config)
  end
end
