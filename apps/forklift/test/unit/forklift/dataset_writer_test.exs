defmodule Forklift.DatasetWriterTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias Forklift.{DataBuffer, DatasetWriter, PersistenceClient}

  describe "perform/1" do
    test "should write new messages to peristence" do
      [data1, data2, data3] = TDG.create_data([dataset_id: "ds1", payload: %{one: 1}], 3)

      entries = [
        %{key: 1, data: data1},
        %{key: 2, data: data2},
        %{key: 3, data: data3}
      ]

      payloads = Enum.map(entries, fn %{data: %{payload: payload}} -> payload end)

      allow DataBuffer.get_unread_data("ds1"), return: entries
      allow DataBuffer.get_pending_data("ds1"), return: []
      allow DataBuffer.mark_complete(any(), any()), return: :ok
      allow DataBuffer.reset_empty_reads(any()), return: :ok
      allow PersistenceClient.upload_data(any(), any()), return: :ok

      DatasetWriter.perform("ds1")

      assert_called PersistenceClient.upload_data("ds1", payloads)
      assert_called DataBuffer.mark_complete("ds1", entries)
      assert_called DataBuffer.reset_empty_reads("ds1")
    end

    test "should write pending messages to peristence" do
      [data1, data2, data3] = TDG.create_data([dataset_id: "ds1", payload: %{one: 1}], 3)

      entries = [
        %{key: 1, data: data1},
        %{key: 2, data: data2},
        %{key: 3, data: data3}
      ]

      payloads = Enum.map(entries, fn %{data: %{payload: payload}} -> payload end)

      allow DataBuffer.get_unread_data("ds1"), return: []
      allow DataBuffer.get_pending_data("ds1"), return: entries
      allow DataBuffer.mark_complete(any(), any()), return: :ok
      allow DataBuffer.cleanup_dataset(any()), return: :ok
      allow DataBuffer.reset_empty_reads(any()), return: :ok
      allow PersistenceClient.upload_data(any(), any()), return: :ok

      DatasetWriter.perform("ds1")

      assert_called PersistenceClient.upload_data("ds1", payloads)
      assert_called DataBuffer.mark_complete("ds1", entries)
      assert_called DataBuffer.cleanup_dataset("ds1")
    end

    test "when pending messages fail to process, should not process new messages" do
      [data1, data2, data3] = TDG.create_data([dataset_id: "ds1", payload: %{one: 1}], 3)
      [data4, data5, data6] = TDG.create_data([dataset_id: "ds1", payload: %{one: 2}], 3)

      unread_entries = [
        %{key: 1, data: data1},
        %{key: 2, data: data2},
        %{key: 3, data: data3}
      ]

      pending_entries = [
        %{key: 4, data: data4},
        %{key: 5, data: data5},
        %{key: 6, data: data6}
      ]

      unread_payloads = Enum.map(unread_entries, fn %{data: %{payload: payload}} -> payload end)

      allow DataBuffer.get_unread_data("ds1"), return: unread_entries
      allow DataBuffer.get_pending_data("ds1"), return: pending_entries
      allow DataBuffer.mark_complete(any(), any()), return: :ok
      allow DataBuffer.cleanup_dataset(any()), return: :ok
      allow PersistenceClient.upload_data(any(), any()), return: {:error, "Write to Presto failed"}

      DatasetWriter.perform("ds1")

      refute_called PersistenceClient.upload_data("ds1", unread_payloads)
    end

    test "when both unread and pending messages return nothing, should cleanup dataset" do
      allow DataBuffer.get_unread_data("ds1"), return: []
      allow DataBuffer.get_pending_data("ds1"), return: []
      allow DataBuffer.mark_complete(any(), any()), return: :ok
      allow DataBuffer.cleanup_dataset(any()), return: :ok
      allow DataBuffer.reset_empty_reads(any()), return: :ok

      DatasetWriter.perform("ds1")

      assert_called DataBuffer.cleanup_dataset("ds1")
    end
  end
end
