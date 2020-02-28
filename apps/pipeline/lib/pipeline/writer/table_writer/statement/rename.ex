defmodule Pipeline.Writer.TableWriter.Statement.Rename do
  @moduledoc """

  """

  def create_new_table_with_existing_table(new_table_name, old_table_name) do
    Statement.create_new_table_with_existing_table()
    |> PrestigeHelper.execute_query()
  end

  def drop_table(table_name) do
    %{table: old_table_name}
    |> Statement.drop()
    |> PrestigeHelper.execute_query()
  end
end
