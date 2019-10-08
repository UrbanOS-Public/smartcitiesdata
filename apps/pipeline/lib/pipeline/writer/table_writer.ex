defmodule Pipeline.Writer.TableWriter do
  @moduledoc "TODO"

  @behaviour Pipeline.Writer
  alias Pipeline.Writer.TableWriter.{Compaction, Statement}
  require Logger

  @impl Pipeline.Writer
  def init(args) do
    config = parse_config(args)

    with {:ok, statement} <- Statement.create(config),
         [[true]] <- execute(statement) do
      Logger.info("Created #{config.name} table")
      :ok
    else
      error ->
        Logger.error("Error creating #{config.name} table: #{inspect(error)}")
        {:error, "Write to Presto failed: #{inspect(error)}"}
    end
  end

  @impl Pipeline.Writer
  def write([], opts) do
    table = Keyword.fetch!(opts, :table)
    Logger.debug("No data to write to #{table}")
    :ok
  end

  def write(content, opts) do
    payloads = Enum.map(content, &Map.get(&1, :payload))

    %{table: Keyword.fetch!(opts, :table), schema: Keyword.fetch!(opts, :schema)}
    |> Statement.insert(payloads)
    |> execute()
    |> case do
      [[_]] -> :ok
      error -> {:error, error}
    end
  end

  @impl Pipeline.Writer
  def compact(args) do
    table = Keyword.fetch!(args, :table)

    Compaction.setup(table)
    |> Compaction.run()
    |> Compaction.measure(table)
    |> Compaction.complete(table)
  end

  @impl Pipeline.Writer
  def terminate(_), do: :ok

  defp parse_config(args) do
    %{
      name: Keyword.fetch!(args, :name),
      schema: Keyword.fetch!(args, :schema)
    }
  end

  defp execute(statement) do
    statement
    |> Prestige.execute()
    |> Prestige.prefetch()
  end
end
