defmodule Estuary.EventTable do
  @moduledoc """
  This module will create event_stream table and insert data in the table
  """

  def create_table do
    Prestige.execute(
      "CREATE TABLE IF NOT EXISTS #{Application.get_env(:estuary, :event_stream_table_name)} (author varchar, create_ts bigint, data varchar, type varchar)"
    )
    |> Prestige.prefetch()
  end
end
