defmodule Estuary.EventTable do
  @moduledoc """
  This modules does the CRUD operation for event_stream in the presto database
  """

  @event_stream_table_name Application.get_env(:estuary, :event_stream_table_name)

  def create_table do
    Prestige.execute(
      "CREATE TABLE IF NOT EXISTS #{@event_stream_table_name} (author varchar, create_ts bigint, data varchar, type varchar)"
    )
    |> Prestige.prefetch()
  end
end
