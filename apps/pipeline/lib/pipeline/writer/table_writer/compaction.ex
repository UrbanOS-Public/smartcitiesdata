defmodule Pipeline.Writer.TableWriter.Compaction do
  @moduledoc false

  alias Pipeline.Writer.TableWriter.Statement
  require Logger

  def setup(table) do
    %{table: "#{table}_compact"}
    |> Statement.drop()
    |> execute()

    table
  end

  def run(table) do
    %{table: "#{table}_compact", as: "select * from #{table}"}
    |> Statement.create()
    |> elem(1)
    |> execute_async()
  end

  def measure(compaction_task, table) do
    with count_task <- execute_async("select count(1) from #{table}"),
         [[orig_count]] <- Task.await(count_task, :infinity),
         _ <- Task.await(compaction_task, :infinity),
         [[new_count]] <- execute("select count(1) from #{table}_compact") do
      {new_count, orig_count}
    end
  end

  def complete({new, old}, table) when new == old do
    compact_table = "#{table}_compact"

    %{table: table}
    |> Statement.drop()
    |> execute()

    %{table: compact_table, alteration: "rename to #{table}"}
    |> Statement.alter()
    |> execute()

    :ok
  end

  def complete({new, old}, table) do
    Statement.drop(%{table: "#{table}_compact"})
    |> execute()

    message = "Failed '#{table}' compaction. New row count (#{new}) did not match original count (#{old})"
    Logger.error(message)

    {:error, message}
  end

  def count(table) do
    with [[count]] <- execute("select count(1) from #{table}") do
      count
    end
  end

  def count_async(table) do
    with task <- execute_async("select count(1) from #{table}"),
         [[count]] <- Task.await(task) do
      count
    end
  end

  defp execute(statement) do
    statement
    |> Prestige.execute()
    |> Prestige.prefetch()
  end

  defp execute_async(statement) do
    Task.async(fn ->
      try do
        execute(statement)
      rescue
        e -> Logger.error("Failed to execute '#{statement}': #{inspect(e)}")
      end
    end)
  end
end
