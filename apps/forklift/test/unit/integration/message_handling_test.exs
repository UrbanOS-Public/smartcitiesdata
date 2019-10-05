defmodule Forklift.Integration.MessageHandlingTest do
  use ExUnit.Case

  import Mox
  alias SmartCity.TestDataGenerator, as: TDG

  setup :set_mox_global
  setup :verify_on_exit!

  describe "on receiving a data message" do
    test "retries to persist to Presto if failing" do
      test = self()
      expect(Forklift.MockTopic, :write, fn _, _ -> :ok end)

      expect(Forklift.MockTable, :write, 5, fn _, _ ->
        send(test, :retry)
        :error
      end)

      expect(Forklift.MockTable, :write, 1, fn _, args ->
        send(test, args[:table])
        :ok
      end)

      dataset = TDG.create_dataset(%{})
      table_name = dataset.technical.systemName

      datum = TDG.create_data(%{dataset_id: dataset.id, payload: %{"foo" => "bar"}})
      message = %Elsa.Message{key: "key_one", value: Jason.encode!(datum)}

      Forklift.MessageHandler.handle_messages([message], %{dataset: dataset})

      assert_receive :retry
      assert_receive ^table_name, 2_000
    end
  end

  test "writes message to topic with timing data" do
    test = self()
    expect(Forklift.MockTable, :write, fn _, _ -> :ok end)
    expect(Forklift.MockTopic, :write, fn msg, _ -> send(test, msg) end)

    dataset = TDG.create_dataset(%{})
    datum = TDG.create_data(%{dataset_id: dataset.id, payload: %{"foo" => "baz"}, operational: %{timing: []}})
    message = %Elsa.Message{key: "key_two", value: Jason.encode!(datum)}

    Forklift.MessageHandler.handle_messages([message], %{dataset: dataset})

    assert_receive [{"key_two", msg}]

    timing = Jason.decode!(msg)["operational"]["timing"]
    assert Enum.count(timing) == 2
    assert Enum.any?(timing, fn time -> time["label"] == "presto_insert_time" end)
    assert Enum.any?(timing, fn time -> time["label"] == "total_time" end)
  end
end
