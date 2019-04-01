defmodule Forklift.DatasetWriterTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias Forklift.{DataBuffer, DatasetWriter, PersistenceClient}

  test "run/1 should write messages to peristence" do
    [data1, data2, data3] = TDG.create_data([dataset_id: "ds1", payload: %{one: 1}], 3)

    entries = [
      %{key: 1, data: data1},
      %{key: 2, data: data2},
      %{key: 3, data: data3}
    ]

    payloads = Enum.map(entries, fn %{data: %{payload: payload}} -> payload end)

    allow DataBuffer.get_pending_data("ds1"), return: entries
    allow DataBuffer.mark_complete(any(), any()), return: :ok
    allow DataBuffer.cleanup_dataset(any(), any()), return: :ok
    allow PersistenceClient.upload_data(any(), any()), return: :ok

    DatasetWriter.run("ds1")

    assert_called PersistenceClient.upload_data("ds1", payloads)
    assert_called DataBuffer.mark_complete("ds1", entries)
    assert_called DataBuffer.cleanup_dataset("ds1", entries)
  end
end
