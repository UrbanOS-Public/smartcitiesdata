defmodule Pipeline.Writer.TableWriter.Helper.PrestigeHelper do
  alias Pipeline.Writer.TableWriter.Statement
  @moduledoc false

  require Logger

  defp prestige_module do
    Application.get_env(:pipeline, :prestige, Prestige)
  end

  def execute_query(query) do
    create_session()
    |> prestige_module().execute(query)
  rescue
    error -> error
  end

  def execute_async_query(statement) do
    Task.async(fn ->
      try do
        execute_query(statement)
      rescue
        e -> Logger.error("Failed to execute '#{statement}': #{inspect(e)}")
      end
    end)
  end

  def create_session() do
    Application.get_env(:prestige, :session_opts)
    |> prestige_module().new_session()
  end

  def drop_table(%{"Table" => table_name}) do
    %{table: table_name}
    |> Statement.drop()
    |> execute_query()
  end

  def drop_table(table_name) do
    %{table: table_name}
    |> Statement.drop()
    |> execute_query()
  end

  def count(table) do
    count_query("select count(1) from #{table}")
  end

  def count!(table) do
    count_query!("select count(1) from #{table}")
  end

  def count_query(query) do
    case execute_query(query) do
      {:ok, response} -> {:ok, extract_count({:ok, response})}
      error -> error
    end
  end

  def count_query!(query) do
    case execute_query(query) do
      {:error, error} -> raise "Failed to get count for #{query}: #{inspect(error)}"
      {:ok, response} -> extract_count({:ok, response})
    end
  end

  defp extract_count({:ok, results}) do
    [[new_row_count]] = results.rows
    new_row_count
  end

  defp extract_count(_), do: :error

  def table_exists?(table) do
    case execute_query("show create table #{table}") do
      {:ok, _} -> true
      _ -> false
    end
  end
end
