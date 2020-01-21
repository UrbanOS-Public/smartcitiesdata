defmodule Estuary.Services.EventRetrievalService do
  @moduledoc """
  Interface for retrieving events.
  """
  alias Estuary.Query.Select

  def get_all() do
    case Select.select_table(make_select_table_schema) do
      {:ok, events} -> events
      {:error, reason} -> raise reason
    end
  end

  defp make_select_table_schema do
    %{
      "columns" => ["author", "create_ts", "data", "type"],
      "table_name" => "event_stream",
      "order_by" => "",
      "order" => "DESC",
      "limit" => 1000
    }
  end
end
