defmodule Pipeline.Writer.S3Writer do
  @moduledoc """
  Implementation of `Pipeline.Writer` for writing to PrestoDB tables via S3.
  """

  @behaviour Pipeline.Writer

  alias Pipeline.Writer.S3Writer.{Compaction, S3SafeJson}
  alias Pipeline.Writer.TableWriter.{Statement}
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias Pipeline.Writer.TableWriter.Helper.TelemetryEventHelper
  alias Pipeline.Writer.TableWriter.Statement.StatementUtils
  alias ExAws.S3

  require Logger
  @type schema() :: [map()]

  @impl Pipeline.Writer
  @spec init(table: String.t(), schema: schema(), bucket: String.t(), json_partitions: [String.t()], main_partitions: [String.t()]) ::
          :ok | {:error, term()}
  @doc """
  Ensures PrestoDB tables exist for JSON and ORC formats.
  """
  def init(options) do
    main_partitions = options |> Keyword.fetch!(:main_partitions)
    json_partitions = options |> Keyword.fetch!(:json_partitions)
    with {:ok, orc_table_name} <- create_table("ORC", options |> Keyword.merge([partitions: main_partitions])),
         {:ok, _json_table_name} <- create_table("JSON", options |> Keyword.merge([partitions: json_partitions])) do
      Logger.info("Created #{orc_table_name} table")
      :ok
    else
      {error, {:ok, statement}} ->
        Logger.error("Error creating table as: #{inspect(statement)}")
        {:error, "Presto table creation failed due to: #{inspect(error)}"}
    end
  end

  @impl Pipeline.Writer
  @spec write([term()], table: String.t(), schema: schema()) :: :ok | {:error, term()}
  @doc """
  Writes data to PrestoDB table via S3.
  """
  def write([], options) do
    table_name = table_name("ORC", options)

    Logger.debug("No data to write to #{table_name}")
    :ok
  end

  def write(content, options) do
    json_config = config("JSON", options)
    bucket = Keyword.fetch!(options, :bucket)

    case table_exists?(json_config) do
      true ->
        if is_partitioned_write(options) do
          :ok = upload_content(content, json_config.schema, json_config.table, bucket, get_partition_folder_path(options))
          {:ok, _} = PrestigeHelper.execute_query(Statement.sync_partition_metadata(json_config.table))
          :ok
        else
          upload_content(content, json_config.schema, json_config.table, bucket)
        end

      {:error, %{name: "TABLE_NOT_FOUND", type: "USER_ERROR"}} ->
        case init(options) do
          :ok -> write(content, options)
          error -> error
        end

      error ->
        error
    end
  end

  defp upload_content(content, schema, table, bucket, partition_folder) do
    source_file_path = write_content_to_temp(content, schema, table)
    destination_file_path = generate_unique_s3_file_path(table, partition_folder)
    upload_to_kdp_s3_folder(bucket, source_file_path, destination_file_path)
  end

  defp upload_content(content, schema, table, bucket) do
    source_file_path = write_content_to_temp(content, schema, table)
    destination_file_path = generate_unique_s3_file_path(table)
    upload_to_kdp_s3_folder(bucket, source_file_path, destination_file_path)
  end

  @impl Pipeline.Writer
  @spec compact(table: String.t()) :: :ok | :skipped | {:error, term()}
  @doc """
  Creates a new, compacted table from the S3 table and the compacted table. Compaction reduces the number of ORC files stored by object storage.
  """
  def compact(options) do
    compaction_options = [
      orc_table: table_name("ORC", options),
      json_table: table_name("JSON", options)
    ]

    if Compaction.skip?(compaction_options) do
      compaction_options[:orc_table]
      |> Compaction.count()
      |> TelemetryEventHelper.add_dataset_record_event_count(compaction_options[:orc_table])

      :skipped
    else
      Compaction.setup(compaction_options)
      |> Compaction.run()
      |> Compaction.measure(compaction_options)
      |> Compaction.complete(compaction_options)
    end
  end

  @impl Pipeline.Writer
  @spec delete(dataset: [term()]) :: :ok | {:error, term()}
  def delete(args) do
    dataset = Keyword.fetch!(args, :dataset)
    new_table_name = StatementUtils.parse_new_table_name(dataset.technical.systemName)
    delete_table("ORC", new_table_name, dataset.technical.systemName)
    delete_table("JSON", new_table_name, dataset.technical.systemName)
  end

  defp write_to_temporary_file(file_contents, table_name) do
    temporary_file_path = Temp.path!(table_name)

    File.write!(temporary_file_path, file_contents, [:compressed])

    temporary_file_path
  end

  defp generate_unique_s3_file_path(table_name, partition_folder) do
    time = DateTime.utc_now() |> DateTime.to_unix() |> to_string()
    "hive-s3/#{table_name}/#{partition_folder}/#{time}-#{System.unique_integer()}.gz"
  end

  defp generate_unique_s3_file_path(table_name) do
    time = DateTime.utc_now() |> DateTime.to_unix() |> to_string()
    "hive-s3/#{table_name}/#{time}-#{System.unique_integer()}.gz"
  end

  defp upload_to_kdp_s3_folder(bucket, source_file_path, destination_file_path) do
    source_file_path
    |> S3.Upload.stream_file()
    |> S3.upload(bucket, destination_file_path)
    |> ExAws.request()
    |> cleanup_file(source_file_path)
    |> case do
      {:ok, _} ->
        :ok

      error ->
        {:error, error}
    end
  end

  defp cleanup_file(passthrough, file_path) do
    File.rm!(file_path)
    passthrough
  end

  defp create_table(format, options) do
    config = config(format, options)

    statement = Statement.create(config)

    case execute(statement) do
      {:error, _} = error -> {error, statement}
      {:ok, _} -> {:ok, config.table}
    end
  end

  defp config(format, options) do
    %{
      table: table_name(format, options),
      schema: options[:schema],
      format: format,
      partitions: options[:partitions]
    }
  end

  defp table_name("ORC", options), do: Keyword.fetch!(options, :table) |> String.downcase()
  defp table_name("JSON", options), do: (Keyword.fetch!(options, :table) <> "__json") |> String.downcase()

  defp execute({:error, _} = error) do
    error
  end

  defp execute({:ok, statement}) do
    try do
      PrestigeHelper.execute_query(statement)
    rescue
      e -> e
    end
  end

  defp execute(statement), do: execute({:ok, statement})

  defp table_exists?(%{table: table}) do
    case execute("show create table #{table}") do
      {:ok, _} -> true
      error -> error
    end
  end

  defp delete_table(type, new_table_name, table_name) do
    table_name = table_name(type, table: table_name)

    table_name(type, table: new_table_name)
    |> StatementUtils.create_new_table_with_existing_table(table_name)

    table_name
    |> StatementUtils.drop_table()
  end

  defp get_partition_folder_path(options) do
    partition_values = Keyword.fetch!(options, :partition_values)
    partition_values |> Enum.map(fn {k, v} -> "#{k}=#{v}" end) |> Enum.join("/")
  end

  defp is_partitioned_write(options) do
    Keyword.has_key?(options, :partition_values)
  end

  defp write_content_to_temp(content, schema, table) do
    content
    |> Enum.map(&Map.get(&1, :payload))
    |> Enum.map(&S3SafeJson.build(&1, schema))
    |> Enum.map(&Jason.encode!/1)
    |> Enum.join("\n")
    |> write_to_temporary_file(table)
  end
end
