defmodule Pipeline.Writer.S3Writer do
  @moduledoc """
  Implementation of `Pipeline.Writer` for writing to PrestoDB tables via S3.
  """

  @behaviour Pipeline.Writer

  alias Pipeline.Writer.S3Writer.{Compaction, S3SafeJson}
  alias Pipeline.Writer.TableWriter.{Statement}
  alias Pipeline.Application
  alias ExAws.S3

  require Logger
  @type schema() :: [map()]

  @impl Pipeline.Writer
  @spec init(table: String.t(), schema: schema()) :: :ok | {:error, term()}
  @doc """
  Ensures PrestoDB tables exist for JSON and ORC formats.
  """
  def init(options) do
    json_config = json_config(options)
    orc_config = orc_config(options)

    with {:ok, statement} <- Statement.create(json_config),
         {:ok, _} <- execute(statement),
         {:ok, statement} <- Statement.create(orc_config),
         {:ok, _} <- execute(statement)  do
      Logger.info("Created #{orc_config.table} table")
      :ok
    else
      error ->
        Logger.error("Error creating #{orc_config.table} table: #{inspect(error)}")
        {:error, "Write to Presto failed: #{inspect(error)}"}
    end
  end

  @impl Pipeline.Writer
  @spec write([term()], table: String.t(), schema: schema()) :: :ok | {:error, term()}
  @doc """
  Writes data to PrestoDB table via S3.
  """
  def write([], options) do
    orc_config = orc_config(options)

    Logger.debug("No data to write to #{orc_config.table}")
    :ok
  end

  def write(content, options) do
    json_config = json_config(options)

    source_file_path = content
    |> Enum.map(&Map.get(&1, :payload))
    |> Enum.map(&S3SafeJson.build(&1, json_config.schema))
    |> Enum.map(&Jason.encode!/1)
    |> Enum.join("\n")
    |> write_to_temporary_file(json_config.table)

    destination_file_path= generate_unique_s3_file_path(json_config.table)

    upload_to_kdp_s3_folder(source_file_path, destination_file_path)
  end

  @impl Pipeline.Writer
  @spec compact(table: String.t()) :: :ok | :skipped | {:error, term()}
  @doc """
  Creates a new, compacted table from the S3 table and the compacted table. Compaction reduces the number of ORC files stored by object storage.
  """
  def compact(options) do
    compaction_options = [
     orc_table: orc_table_name(options),
     json_table: json_table_name(options)
    ]

    if Compaction.skip?(compaction_options) do
      :skipped
    else
      Compaction.setup(compaction_options)
      |> Compaction.run()
      |> Compaction.measure(compaction_options)
      |> Compaction.complete(compaction_options)
    end
  end

  defp write_to_temporary_file(file_contents, table_name) do
    temporary_file_path = Temp.path!(table_name)

    File.write!(temporary_file_path, file_contents, [:compressed])

    temporary_file_path
  end

  defp generate_unique_s3_file_path(table_name) do
    time = DateTime.utc_now |> DateTime.to_unix |> to_string()
    "hive-s3/#{table_name}/#{time}-#{System.unique_integer}.gz"
  end

  defp upload_to_kdp_s3_folder(source_file_path, destination_file_path) do
    source_file_path
    |> S3.Upload.stream_file()
    |> S3.upload("kdp-cloud-storage", destination_file_path)
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

  defp orc_config(options) do
    %{
      table: orc_table_name(options),
      schema: Keyword.fetch!(options, :schema)
    }
  end

  defp json_config(options) do
    %{
      table: json_table_name(options),
      schema: Keyword.fetch!(options, :schema),
      format: "JSON"
    }
  end

  defp orc_table_name(options), do: Keyword.fetch!(options, :table)
  defp json_table_name(options), do: orc_table_name(options) <> "__json"

  defp execute(statement) do
    try do
      Application.prestige_opts() |> Prestige.new_session() |> Prestige.execute(statement)
    rescue
      e -> e
    end
  end
end
