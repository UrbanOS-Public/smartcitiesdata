defmodule Pipeline.Writer.TableWriter.Statement.StatementUtils do
  @moduledoc false

  alias Pipeline.Writer.TableWriter.Statement
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper

  def create_new_table_with_existing_table(new_table_name, table_name) do
    %{new_table_name: new_table_name, table_name: table_name}
    |> Statement.create_new_table_with_existing_table()
    |> PrestigeHelper.execute_query()
  end

  def drop_table(table_name) do
    %{table: table_name}
    |> Statement.drop()
    |> PrestigeHelper.execute_query()
  end

  def parse_new_table_name(table_name) do
    "deleted__#{current_timestamp()}__#{table_name}"
  end

  def delete_ingestion_data_from_table(table_name, ingestion_id) do
    Statement.delete_ingestion_data_from_table(table_name, ingestion_id)
    |> PrestigeHelper.execute_query()
  end

  defp current_timestamp() do
    DateTime.utc_now()
    |> DateTime.to_unix(:millisecond)
  end
end
