defmodule Estuary.DataWriterTest do
  use ExUnit.Case
  use Placebo

  alias Estuary.Datasets.DatasetSchema
  alias Estuary.DataWriter
  alias SmartCity.TestDataGenerator, as: TDG

  test "should insert event to history table" do
    allow(MockTable.write(any(), any()), return: :ok)
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

    assert_called(MockTable.write(payload, table: table, schema: schema))
  end
end
