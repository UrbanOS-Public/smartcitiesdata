defmodule Estuary.Services.EventRetrievalService do
  @moduledoc """
  Interface for retrieving events.
  """
  alias Estuary.Query.Select
  alias Estuary.Datasets.DatasetSchema
  alias Estuary.Query.Helper.PrestigeHelper

  def get_all do
    make_select_table_sub_schema()
    |> Select.create_select_statement()
    |> make_select_table_schema()
    |> Select.create_select_statement()
    |> PrestigeHelper.execute_query()
  end

  defp make_select_table_schema(events) do
    %{
      "columns" => ["events.author", "events.create_ts", "events.data", "events.type"],
      "table_name" => "(#{events}) events",
      "order_by" => "events.create_ts",
      "order" => "DESC"
    }
  end

  defp make_select_table_sub_schema do
    %{
      "columns" => ["author", "create_ts", "data", "type"],
      "table_name" => DatasetSchema.table_name(),
      "conditions" => ["create_ts >= to_unixtime(now() - interval '3' hour)"],
      "limit" => 1000
    }
  end
end
