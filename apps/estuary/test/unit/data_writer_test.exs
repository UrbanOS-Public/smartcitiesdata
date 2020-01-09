defmodule Estuary.DataWriterTest do
  use ExUnit.Case
  import Mox

  alias Estuary.Datasets.DatasetSchema
  alias Estuary.DataWriter
  alias SmartCity.TestDataGenerator, as: TDG

  setup :set_mox_global
  setup :verify_on_exit!

  test "should insert event to history table" do
    test = self()

    expect(MockTable, :write, 1, fn payload, args ->
      send(test, %{
        payload: payload,
        table: Keyword.get(args, :table),
        schema: Keyword.get(args, :schema)
      })

      :ok
    end)

    author = "A nice fellow"
    time_stamp = DateTime.to_unix(DateTime.utc_now())
    dataset = Jason.encode!(TDG.create_dataset(%{}))

    table = DatasetSchema.table_name()
    schema = DatasetSchema.schema()

    DataWriter.write(%{
      "author" => author,
      "create_ts" => time_stamp,
      "data" => dataset,
      "forwarded" => false,
      "type" => "data:ingest:start"
    })

    payload = [
      %{
        payload: %{
          "author" => author,
          "create_ts" => time_stamp,
          "data" => dataset,
          "type" => "data:ingest:start"
        }
      }
    ]

    expected = %{
      payload: payload,
      table: table,
      schema: schema
    }

    assert_receive(^expected)
  end
end
