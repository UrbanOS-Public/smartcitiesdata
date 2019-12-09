defmodule Estuary.EventTableHelper do
  @event_stream_table_name Application.get_env(:estuary, :event_stream_table_name)

  def select_table_data(author) do
    "SELECT author, create_ts, data, type FROM #{@event_stream_table_name}
    WHERE author IN (#{author}) ORDER BY author"
    |> Prestige.execute()
    |> Prestige.prefetch()
  end

  def delete_table_data() do
    "DELETE FROM #{@event_stream_table_name}"
    |> Prestige.execute()
    |> Stream.run()
  end
end
