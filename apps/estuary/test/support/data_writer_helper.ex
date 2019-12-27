defmodule Estuary.DataWriterHelper do
  @moduledoc false

  @table_name Application.get_env(:estuary, :table_name)

  def get_events_by_author(author) do
    "SELECT author, create_ts, data, type
      FROM #{@table_name}
      WHERE author IN (#{author})
      ORDER BY author"
    |> Prestige.execute()
    |> Prestige.prefetch()
  end

  def delete_all_events_in_table() do
    "DELETE FROM #{@table_name}"
    |> Prestige.execute()
    |> Stream.run()
  end

  def make_author do
    DateTime.utc_now()
    |> to_string()
  end

  def make_time_stamp do
    DateTime.utc_now()
    |> DateTime.to_unix()
  end
end
