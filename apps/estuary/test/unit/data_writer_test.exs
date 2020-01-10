defmodule Estuary.DataWriterTest do
  use ExUnit.Case
  import Mox

  alias Estuary.Datasets.DatasetSchema
  alias Estuary.DataWriter
  alias SmartCity.TestDataGenerator, as: TDG

  setup :set_mox_global
  setup :verify_on_exit!

  test "should insert events to history table" do
    test = self()

    expect(MockTable, :write, 1, fn payload, args ->
      send(test, %{
        payload: payload,
        table: Keyword.get(args, :table),
        schema: Keyword.get(args, :schema)
      })

      :ok
    end)

    table = DatasetSchema.table_name()
    schema = DatasetSchema.schema()

    eventA = %{
      "author" => "A nice fellow",
      "create_ts" => DateTime.to_unix(DateTime.utc_now()),
      "data" => Jason.encode!(TDG.create_dataset(%{})),
      "forwarded" => false,
      "type" => "data:ingest:start"
    }

    eventB = %{
      "author" => "A mean fellow",
      "create_ts" => DateTime.to_unix(DateTime.utc_now()),
      "data" => Jason.encode!(TDG.create_dataset(%{})),
      "forwarded" => false,
      "type" => "data:ingest:end"
    }

    DataWriter.write([eventA, eventB])

    payload = [
      %{
        payload: %{
          "author" => eventA["author"],
          "create_ts" => eventA["create_ts"],
          "data" => eventA["data"],
          "type" => eventA["type"]
        }
      },
      %{
        payload: %{
          "author" => eventB["author"],
          "create_ts" => eventB["create_ts"],
          "data" => eventB["data"],
          "type" => eventB["type"]
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
