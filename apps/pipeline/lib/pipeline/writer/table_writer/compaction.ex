defmodule Pipeline.Writer.TableWriter.Compaction do
  @moduledoc false
  alias Pipeline.Writer.TableWriter.Statement
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias Pipeline.Writer.TableWriter.Helper.TelemetryEventHelper
  require Logger

  def setup(table) do
    %{table: "#{table}_compact"}
    |> Statement.drop()
    |> PrestigeHelper.execute_query()

    table
  end

  def run(table) do
    %{table: "#{table}_compact", as: "select * from #{table}"}
    |> Statement.create()
    |> elem(1)
    |> PrestigeHelper.execute_async_query()
  end

  def measure(compaction_task, table) do
    with count_task <- PrestigeHelper.execute_async_query("select count(1) from #{table}"),
         {:ok, orig_results} <- Task.await(count_task, :infinity),
         _ <- Task.await(compaction_task, :infinity),
         {:ok, new_results} <- PrestigeHelper.execute_query("select count(1) from #{table}_compact") do
      [[new_row_count]] = new_results.rows
      [[old_row_count]] = orig_results.rows
      {new_row_count, old_row_count}
    end
  end

  def complete({new, old}, table) when new == old do
    compact_table = "#{table}_compact"

    %{table: table}
    |> Statement.drop()
    |> PrestigeHelper.execute_query()

    %{table: compact_table, alteration: "rename to #{table}"}
    |> Statement.alter()
    |> PrestigeHelper.execute_query()

    TelemetryEventHelper.add_dataset_record_event_count(new, table)

    :ok
  end

  def complete({new, old}, table) do
    Statement.drop(%{table: "#{table}_compact"})
    |> PrestigeHelper.execute_query()

    message = "Failed '#{table}' compaction. New row count (#{new}) did not match original count (#{old})"
    Logger.error(message)

    {:error, message}
  end

  def count(table) do
    with {:ok, results} <- PrestigeHelper.execute_query("select count(1) from #{table}") do
      results.rows
    end
  end

  def count_async(table) do
    with task <- PrestigeHelper.execute_async_query("select count(1) from #{table}"),
         {:ok, results} <- Task.await(task) do
      results.rows
    end
  end
end
