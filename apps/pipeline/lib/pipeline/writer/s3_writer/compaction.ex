defmodule Pipeline.Writer.S3Writer.Compaction do
  @moduledoc false
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias Pipeline.Writer.TableWriter.Helper.TelemetryEventHelper
  alias Pipeline.Writer.TableWriter.Statement
  require Logger
  use Retry

  @initial_wait 100
  @max_wait 15_000
  @retry_count 100

  def setup(options) do
    orc_table = options[:orc_table]
    orc_table_exists = table_exists?(orc_table)
    compact_table = "#{orc_table}_compact"
    compact_table_exists = table_exists?(compact_table)

    cond do
      !orc_table_exists && !compact_table_exists ->
        raise RuntimeError,
              "Critical Error: Compaction for #{orc_table} failed due to missing tables. Data for the associated dataset has been lost. Recommend restoring from backup."

      compact_table_exists && !orc_table_exists ->
        Logger.warn(
          "Table #{orc_table} not found during compaction. Restoring the table from the previous run's compacted table."
        )

        rename_and_validate(compact_table, orc_table)

      compact_table_exists ->
        ensure_table_dropped(compact_table)

      true ->
        :ok
    end

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

    ensure_table_dropped(orc_table)

    truncate_and_drain(json_table)

    rename_and_validate(compact_table, orc_table)

    TelemetryEventHelper.add_dataset_record_event_count(new_count, orc_table)

    :ok
  end

  def complete({new_count, old_count}, options) do
    orc_table = options[:orc_table]
    compact_table = "#{orc_table}_compact"

    Statement.drop(%{table: compact_table})
    |> PrestigeHelper.execute_query()

    message =
      "Failed '#{orc_table}' compaction. New row count (#{inspect(new_count)}) did not match original count (#{inspect(old_count)})"

    Logger.error(message)

    {:error, message}
  end

  def wait_for_record_count(table, target_count) do
    retry with: exponential_backoff(@initial_wait) |> cap(@max_wait) |> Stream.take(@retry_count) do
      case count(table) do
        current_count when current_count == target_count -> :ok
        _ -> :error
      end
    after
      _ -> :ok
    else
      {:error, reason} ->
        raise RuntimeError,
              "Aborting compaction. Unable to confirm new record count (#{target_count}) for #{table} due to: #{inspect(reason)}"
    end
  end

  def count(table) do
    case PrestigeHelper.execute_query("select count(1) from #{table}") do
      {:ok, new_results} ->
        [[new_row_count]] = new_results.rows
        new_row_count

      _ ->
        :error
    end
  end

  def count_async(table) do
    with task <- PrestigeHelper.execute_async_query("select count(1) from #{table}"),
         {:ok, results} <- Task.await(task) do
      results.rows
    end
  end

  # This function checks to make sure Hive has finished deleting all source files before continuing.
  # It does so by attempting to recreate the table and failing until all files have been removed.
  defp ensure_table_dropped(table) do
    drop_table(table)

    retry with: exponential_backoff(@initial_wait) |> cap(@max_wait) |> Stream.take(@retry_count) do
      PrestigeHelper.execute_query("create table #{table} (delete_me int)")
    after
      _ ->
        drop_table(table)
    else
      error ->
        drop_table(table)
        raise RuntimeError, inspect(error)
    end
  end

  defp rename_and_validate(source_table, target_table) do
    source_count = count(source_table)

    %{table: source_table, alteration: "rename to #{target_table}"}
    |> Statement.alter()
    |> PrestigeHelper.execute_query()

    wait_for_record_count(target_table, source_count)
  end

  defp truncate_and_drain(target_table) do
    %{table: target_table}
    |> Statement.truncate()
    |> PrestigeHelper.execute_query()

    wait_for_record_count(target_table, 0)
  end

  defp drop_table(table) do
    %{table: table}
    |> Statement.drop()
    |> PrestigeHelper.execute_query()
  end

  defp table_exists?(table) do
    case PrestigeHelper.execute_query("show create table #{table}") do
      {:ok, _} -> true
      _ -> false
    end
  end
end
