defmodule Pipeline.Writer.TableWriter.Statement.Rename do
  @moduledoc false

  alias Pipeline.Writer.TableWriter.Statement
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper

  def create_new_table_with_existing_table(dataset) do
    table_name = parse_table_name(dataset)
    new_table_name = parse_new_table_name(table_name)

    %{new_table_name: new_table_name, table_name: table_name}
    |> Statement.create_new_table_with_existing_table()
    |> PrestigeHelper.execute_query()
  end

  def drop_table(dataset) do
    table_name = parse_table_name(dataset)

    %{table: table_name}
    |> Statement.drop()
    |> PrestigeHelper.execute_query()
  end

  defp parse_table_name(dataset) do
    "#{dataset.technical.orgName}__#{dataset.technical.dataName}"
  end

  defp parse_new_table_name(table_name) do
    "deleted__#{current_timestamp()}__#{table_name}"
  end

  defp current_timestamp() do
    DateTime.utc_now()
    |> DateTime.to_unix(:millisecond)
  end
end
