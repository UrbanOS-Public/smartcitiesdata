defmodule Estuary.EventTableHelper do
  @moduledoc false
#   @event_stream_schema_name Application.get_env(:estuary, :event_stream_schema_name)
#   @event_stream_table_name Application.get_env(:estuary, :event_stream_table_name)

  def get_events_by_author(author) do
    "SELECT author, create_ts, data, type
    FROM history
    WHERE author IN (#{author})
    ORDER BY author"
    |> Prestige.execute()
    |> Prestige.prefetch()
  end

  def delete_all_events_in_table() do
    "DELETE FROM history"
    |> Prestige.execute()
    |> Stream.run()
  end
end
