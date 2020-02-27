defmodule Pipeline.Writer.TableWriter.Statement.Rename do
  @moduledoc false
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper

  def compose(new_table_name, old_table_name) do
    %{table: "#{new_table_name}", as: "select * from #{old_table_name}"}
    |> Statement.create()
    |> elem(1)
    |> PrestigeHelper.execute_async_query()
  end

  # def measure(new_table_name, old_table_name) do
  #   with count_task <- PrestigeHelper.execute_async_query("select count(1) from #{old_table_name}"),
  #        {:ok, old_table_results} <- Task.await(count_task, :infinity),
  #        _ <- Task.await(compaction_task, :infinity),
  #        {:ok, new_table_results} <- PrestigeHelper.execute_query("select count(1) from #{new_table_name}") do
  #     [[new_table_row_count]] = new_table_results.rows
  #     [[old_table_row_count]] = old_table_results.rows
  #     {new_table_row_count, old_table_row_count}
  #   end
  # end
end
