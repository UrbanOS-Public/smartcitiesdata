defmodule Estuary.Services.EventRetrievalService do
  @moduledoc """
  Interface for retrieving events.
  """
  alias Estuary.Query.Select
  alias Estuary.Datasets.DatasetSchema

  def get_all() do
    make_select_table_schema()
    |> Select.select_table()
  end

  defp make_select_table_schema do
    %{
      "columns" => ["author", "create_ts", "data", "type"],
      "table_name" => DatasetSchema.table_name(),
      "order_by" => "create_ts",
      "order" => "DESC",
      "limit" => 1000
    }
  end
end
