defmodule Pipeline.Writer.TableWriter do
  @moduledoc """
  Implementation of `Pipeline.Writer` for PrestoDB tables.
  """

  @behaviour Pipeline.Writer
  alias Pipeline.Writer.TableWriter.{Compaction, Statement}
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias Pipeline.Writer.TableWriter.Statement.StatementUtils
  require Logger

  @type schema() :: [map()]

  @impl Pipeline.Writer
  @spec init(table: String.t(), schema: schema()) :: :ok | {:error, term()}
  @doc """
  Ensures PrestoDB table exists.
  """
  def init(args) do
    config = parse_args(args)

    with {:ok, statement} <- Statement.create(config),
         {:ok, _} <- PrestigeHelper.execute_query(statement) do
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
    payloads = Enum.map(content, &Map.get(&1, :payload))

    parse_args(config)
    |> Statement.insert(payloads)
    |> PrestigeHelper.execute_query()
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

  @impl Pipeline.Writer
  @spec delete(dataset: [term()]) :: :ok | {:error, term()}
  def delete(args) do
    dataset = Keyword.fetch!(args, :dataset)

    StatementUtils.parse_new_table_name(dataset.technical.systemName)
    |> StatementUtils.create_new_table_with_existing_table(dataset.technical.systemName)

    StatementUtils.drop_table(dataset.technical.systemName)
  end

  @impl Pipeline.Writer
  def delete_ingestion_data(ingestion, dataset) do
    StatementUtils.delete_ingestion_data_from_table(dataset.technical.systemName, ingestion.id)
  end

  defp parse_args(args) do
    %{
      table: Keyword.fetch!(args, :table),
      schema: Keyword.fetch!(args, :schema)
    }
  end
end
