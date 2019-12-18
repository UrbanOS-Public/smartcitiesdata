defmodule Estuary.EventTable do
  @moduledoc """
  This module will create event_stream table and insert data in the table
  """

  def create_schema do
    "CREATE SCHEMA IF NOT EXISTS hive.#{schema_name()}"
    |> Prestige.execute()
    |> Prestige.prefetch()
  rescue
    error -> {:error, error}
  end

  def create_table do
    "CREATE TABLE IF NOT EXISTS #{schema_name()}.#{table_name()}
    (author varchar, create_ts bigint, data varchar, type varchar)"
    |> Prestige.execute()
    |> Prestige.prefetch()
  rescue
    error -> {:error, error}
  end

  def insert_event_to_table(event_value) do
    "INSERT INTO #{schema_name()}.#{table_name()}
      (author, create_ts, data, type)
      VALUES
      ('#{event_value["author"]}', #{event_value["create_ts"]},
      '#{event_value["data"]}', '#{event_value["type"]}')"
    |> Prestige.execute()
    |> Stream.run()
  rescue
    error in Prestige.Error -> {:error, error}
  end

  defp schema_name do
    Application.get_env(:estuary, :event_stream_schema_name)
  end

  defp table_name do
    Application.get_env(:estuary, :event_stream_table_name)
  end
end
