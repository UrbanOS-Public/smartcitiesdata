defmodule Pipeline.Writer.S3Writer.Compaction do
  @moduledoc false
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias Pipeline.Writer.TableWriter.Statement
  require Logger

  def setup(options) do
    orc_table = options[:orc_table]

    %{table: "#{orc_table}_compact"}
    |> Statement.drop()
    |> PrestigeHelper.execute_query()

    options
  end

  def run(options) do
    orc_table = options[:orc_table]
    json_table = options[:json_table]
    compact_table = "#{orc_table}_compact"

    %{
      table: compact_table,
      as: Statement.union(orc_table, json_table)
    }
    |> Statement.create()
    |> elem(1)
    |> PrestigeHelper.execute_async_query()
  end

  def skip?(options) do
    json_table = options[:json_table]

    case PrestigeHelper.execute_query("select count(1) from #{json_table}") do
      {:ok, %{rows: [[0]]}} -> true
      {:error, _} -> true
      _ -> false
    end
  end

  def measure(compaction_task, options) do
    orc_table = options[:orc_table]
    json_table = options[:json_table]
    union_statement = Statement.union(orc_table, json_table)

    with count_task <-
           PrestigeHelper.execute_async_query("select count(1) from (#{union_statement})"),
         {:ok, orig_results} <- Task.await(count_task, :infinity),
         _ <- Task.await(compaction_task, :infinity),
         {:ok, new_results} <- PrestigeHelper.execute_query("select count(1) from #{orc_table}_compact") do
      [[new_row_count]] = new_results.rows
      [[old_row_count]] = orig_results.rows
      {new_row_count, old_row_count}
    end
  end

  def complete({new_count, old_count}, options) when new_count == old_count do
    orc_table = options[:orc_table]
    json_table = options[:json_table]
    compact_table = "#{orc_table}_compact"

    %{table: orc_table}
    |> Statement.drop()
    |> PrestigeHelper.execute_query()

    %{table: json_table}
    |> Statement.truncate()
    |> PrestigeHelper.execute_query()

    %{table: compact_table, alteration: "rename to #{orc_table}"}
    |> Statement.alter()
    |> PrestigeHelper.execute_query()

    :ok
  end

  def complete({new_count, old_count}, options) do
    orc_table = options[:orc_table]
    compact_table = "#{orc_table}_compact"

    Statement.drop(%{table: compact_table})
    |> PrestigeHelper.execute_query()

    message =
      "Failed '#{orc_table}' compaction. New row count (#{inspect(new_count)}) did not match original count (#{
        inspect(old_count)
      })"

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
