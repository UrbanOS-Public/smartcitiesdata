defmodule Pipeline.Writer.S3Writer.Compaction do
  @moduledoc false
  alias Pipeline.Application
  alias Pipeline.Writer.TableWriter.Statement
  require Logger

  def setup(options) do
    orc_table = options[:orc_table]

    %{table: "#{orc_table}_compact"}
    |> Statement.drop()
    |> execute()

    options
  end

  def run(options) do
    orc_table = options[:orc_table]
    json_table = options[:json_table]
    compact_table = "#{orc_table}_compact"

    %{
      table: compact_table,
      as: "select * from #{orc_table} union all select * from #{json_table}"
    }
    |> Statement.create()
    |> elem(1)
    |> execute_async()
  end

  def skip?(options) do
    json_table = options[:json_table]
    case execute("select count(1) from #{json_table}") do
      {:ok, %{rows: [[0]]}} -> true
      _ -> false
    end
  end

  def measure(compaction_task, options) do
    orc_table = options[:orc_table]
    json_table = options[:json_table]

    with count_task <- execute_async("select count(1) from (select * from #{orc_table} union all select * from #{json_table})"),
         {:ok, orig_results} <- Task.await(count_task, :infinity),
         _ <- Task.await(compaction_task, :infinity),
         {:ok, new_results} <- execute("select count(1) from #{orc_table}_compact") do
      [[new_row_count]] = new_results.rows
      [[old_row_count]] = orig_results.rows
      {new_row_count, old_row_count}
    end
  end

  def complete({new, old}, options) when new == old do
    orc_table = options[:orc_table]
    json_table = options[:json_table]
    compact_table = "#{orc_table}_compact"

    %{table: orc_table}
    |> Statement.drop()
    |> execute()

    %{table: json_table}
    |> Statement.truncate()
    |> execute()

    %{table: compact_table, alteration: "rename to #{orc_table}"}
    |> Statement.alter()
    |> execute()
    :ok
  end

  def complete({new, old}, options) do
    orc_table = options[:orc_table]
    compact_table = "#{orc_table}_compact"

    Statement.drop(%{table: compact_table})
    |> execute()

    message = "Failed '#{orc_table}' compaction. New row count (#{inspect(new)}) did not match original count (#{inspect(old)})"
    Logger.error(message)

    {:error, message}
  end

  def count(table) do
    with {:ok, results} <- execute("select count(1) from #{table}") do
      results.rows
    end
  end

  def count_async(table) do
    with task <- execute_async("select count(1) from #{table}"),
         {:ok, results} <- Task.await(task) do
      results.rows
    end
  end

  defp execute(statement) do
    try do
      Application.prestige_opts()
      |> Prestige.new_session()
      |> Prestige.execute(statement)
    rescue
      e -> e
    end
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
