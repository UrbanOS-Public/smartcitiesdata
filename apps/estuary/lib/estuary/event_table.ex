defmodule Estuary.EventTable do
  @moduledoc """
  This module will create event_stream table and insert data in the table
  """

  def create_table do
    Prestige.execute(
      "CREATE TABLE IF NOT EXISTS #{get_table_name()} (author varchar, create_ts bigint, data varchar, type varchar)"
    )
    |> Prestige.prefetch()
  end

  defp get_table_name do
    Application.get_env(:estuary, :event_stream_table_name)
  end
end
