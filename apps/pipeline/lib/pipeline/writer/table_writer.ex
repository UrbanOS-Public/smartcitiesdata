defmodule Pipeline.Writer.TableWriter do
  @moduledoc """
  Implementation of `Pipeline.Writer` for PrestoDB tables.
  """

  @behaviour Pipeline.Writer
  alias Pipeline.Writer.TableWriter.{Compaction, Statement}
  alias Pipeline.Application
  alias ExAws.S3
  require Logger

  @type schema() :: [map()]

  @impl Pipeline.Writer
  @spec init(table: String.t(), schema: schema()) :: :ok | {:error, term()}
  @doc """
  Ensures PrestoDB table exists.
  """
  def init(args) do
    config = parse_args(args)

    json_config = %{
      table: config[:table] <> "_json",
      schema: config[:schema],
      format: "JSON"
    }

    with {:ok, statement} <- Statement.create(config),
         {:ok, _} <- execute(statement),
         {:ok, statement} <- Statement.create(json_config),
         {:ok, _} <- execute(statement) do
      Logger.info("Created #{config.table} table")
      :ok
    else
      error ->
        Logger.error("Error creating #{config.table} table: #{inspect(error)}")
        {:error, "Write to Presto failed: #{inspect(error)}"}
    end
  end

  @impl Pipeline.Writer
  @spec write([term()], table: String.t(), schema: schema()) :: :ok | {:error, term()}
  @doc """
  Writes data to PrestoDB table.
  """
  def write([], config) do
    table = Keyword.fetch!(config, :table)
    Logger.debug("No data to write to #{table}")
    :ok
  end

  def write(content, config) do
    args = parse_args(config)

    payloads = Enum.map(content, &Map.get(&1, :payload))
    File.write!(config[:table], Jason.encode!(payloads))

    # time = DateTime.utc_now |> DateTime.to_unix |> to_string()
    # file_name = "hive-s3/#{config[:table]}_json/#{time}-#{System.unique_integer}"
    # config[:table]
    # |> S3.Upload.stream_file()
    # |> S3.upload("kdp-cloud-storage", "hive-s3/" <> config[:table] <> "_json/" <> time)
    # |> ExAws.request()
    # |> IO.inspect(label: "table_writer.ex:61")
    args
    |> Map.put(:table, config.table <> "_json")
    |> Statement.insert(payloads)
    |> execute()
    |> IO.inspect(label: "table_writer.ex:69")

    args
    |> Statement.insert(payloads)
    |> execute()
    |> case do
      {:ok, _} -> :ok
      error -> {:error, error}
    end
  end

  @impl Pipeline.Writer
  @spec compact(table: String.t()) :: :ok | {:error, term()}
  @doc """
  Creates a new, compacted table from a table. Compaction reduces the number
  of ORC files stored by object storage.
  """
  def compact(args) do
    table = Keyword.fetch!(args, :table)

    Compaction.setup(table)
    |> Compaction.run()
    |> Compaction.measure(table)
    |> Compaction.complete(table)
  end

  defp parse_args(args) do
    %{
      table: Keyword.fetch!(args, :table),
      schema: Keyword.fetch!(args, :schema)
    }
  end

  defp execute(statement) do
    try do
      Application.prestige_opts() |> Prestige.new_session() |> Prestige.execute(statement)
    rescue
      e -> e
    end
  end
end
