defmodule Forklift.MessageHandlingTest do
  use ExUnit.Case
  import Mox

  import SmartCity.Event, only: [data_write_complete: 0]
  alias SmartCity.TestDataGenerator, as: TDG

  @instance_name Forklift.instance_name()

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    # Configure the app to use our mocks
    Application.put_env(:forklift, :table_writer, MockTable)
    Application.put_env(:forklift, :topic_writer, MockTopic)
    Application.put_env(:forklift, :profiling_enabled, true)
    Application.put_env(:forklift, :retry_count, 6)
    Application.put_env(:forklift, :retry_initial_delay, 10)
    Application.put_env(:forklift, :retry_max_wait, 100)

    # Setup test environment
    Brook.Test.register(@instance_name)

    :ok
  end

  test "retries to persist to Presto if failing" do
    test = self()

    # Set up mocks
    expect(MockTopic, :write, fn _, _ -> :ok end)

    expect(MockTable, :write, 5, fn _, _ ->
      send(test, :retry)
      :error
    end)

    expect(MockTable, :write, 1, fn _, args ->
      send(test, args[:table])
      :ok
    end)

    # Create test data
    dataset = TDG.create_dataset(%{})
    table_name = dataset.technical.systemName
    datum = TDG.create_data(%{dataset_id: dataset.id, payload: %{"foo" => "bar"}})
    message = %Elsa.Message{key: "key_one", value: Jason.encode!(datum)}

    # Execute function under test
    Forklift.MessageHandler.handle_messages([message], %{dataset: dataset})

    # Verify behavior
    assert_receive :retry
    assert_receive ^table_name, 2_000

    # Verify a data_write_complete event was sent
    assert_event_sent(data_write_complete(), fn event ->
      event.id == dataset.id
    end)

    wait_for_mox()
  end

  test "writes message to topic with timing data" do
    test = self()

    # Set up mocks
    expect(MockTable, :write, fn _, _ -> :ok end)
    expect(MockTopic, :write, fn msg, _ -> send(test, msg) end)

    # Create test data
    dataset = TDG.create_dataset(%{})
    datum = TDG.create_data(%{dataset_id: dataset.id, payload: %{"foo" => "baz"}, operational: %{timing: []}})
    message = %Elsa.Message{key: "key_two", value: Jason.encode!(datum)}

    # Execute function under test
    Forklift.MessageHandler.handle_messages([message], %{dataset: dataset})

    # Verify behavior
    assert_receive [{"key_two", msg}]
    timing = Jason.decode!(msg)["operational"]["timing"]
    assert Enum.count(timing) == 2
    assert Enum.any?(timing, fn time -> time["label"] == "presto_insert_time" end)
    assert Enum.any?(timing, fn time -> time["label"] == "total_time" end)

    # Verify a data_write_complete event was sent
    assert_event_sent(data_write_complete(), fn event ->
      event.id == dataset.id
    end)

    wait_for_mox()
  end

  test "sends 'dataset:write_complete event' with timestamp after writing records" do
    # Set up mocks
    expect(MockTable, :write, 2, fn _, _ -> :ok end)
    expect(MockTopic, :write, fn _, _ -> :ok end)

    # Create test data
    dataset = TDG.create_dataset(%{})
    datum1 = TDG.create_data(%{dataset_id: dataset.id, payload: %{"foo" => "bar"}})
    datum2 = TDG.create_data(%{dataset_id: dataset.id, payload: %{"foz" => "baz"}})
    message1 = %Elsa.Message{key: "one", value: Jason.encode!(datum1)}
    message2 = %Elsa.Message{key: "two", value: Jason.encode!(datum2)}

    now = DateTime.utc_now()

    # Execute function under test
    Forklift.MessageHandler.handle_messages([message1, message2], %{dataset: dataset})

    # Verify a data_write_complete event was sent with a timestamp after now
    assert_event_sent(data_write_complete(), fn event ->
      event.id == dataset.id &&
        timestamp_after?(event.timestamp, now)
    end)

    wait_for_mox()
  end

  test "handles errors gracefully" do
    # Set up mocks
    stub(MockTable, :write, fn _, _ -> {:error, :raisins} end)
    stub(MockTopic, :write, fn _, _ -> :ok end)

    # Create test data
    dataset = TDG.create_dataset(%{})
    datum1 = TDG.create_data(%{dataset_id: dataset.id, payload: %{"foo" => "bar"}})
    datum2 = TDG.create_data(%{dataset_id: dataset.id, payload: %{"foz" => "baz"}})
    message1 = %Elsa.Message{key: "one", value: Jason.encode!(datum1)}
    message2 = %Elsa.Message{key: "two", value: Jason.encode!(datum2)}

    # Verify exception is raised
    assert_raise RuntimeError, fn ->
      Forklift.MessageHandler.handle_messages([message1, message2], %{dataset: dataset})
    end
  end

  @tag :capture_log
  test "handles topic writer errors gracefully" do
    # Set up mocks
    stub(MockTable, :write, fn _, _ -> :ok end)
    stub(MockTopic, :write, fn _, _ -> raise "something bad happened, but we don't care" end)

    # Create test data
    dataset = TDG.create_dataset(%{})
    datum1 = TDG.create_data(%{dataset_id: dataset.id, payload: %{"foo" => "bar"}})
    datum2 = TDG.create_data(%{dataset_id: dataset.id, payload: %{"foz" => "baz"}})
    message1 = %Elsa.Message{key: "one", value: Jason.encode!(datum1)}
    message2 = %Elsa.Message{key: "two", value: Jason.encode!(datum2)}

    # Verify no exception is raised despite topic writer failing
    assert {:ack, _} = Forklift.MessageHandler.handle_messages([message1, message2], %{dataset: dataset})

    # Verify a data_write_complete event was sent
    assert_event_sent(data_write_complete(), fn event ->
      event.id == dataset.id
    end)
  end

  test "should return empty timing data when profiling is set to false" do
    # Disable profiling for this test
    Application.put_env(:forklift, :profiling_enabled, false)

    test = self()

    # Set up mocks
    expect(MockTable, :write, fn _, _ -> :ok end)
    expect(MockTopic, :write, fn msg, _ -> send(test, msg) end)

    # Create test data
    dataset = TDG.create_dataset(%{})
    datum = TDG.create_data(%{dataset_id: dataset.id, payload: %{"foo" => "baz"}, operational: %{timing: []}})
    message = %Elsa.Message{key: "key_two", value: Jason.encode!(datum)}

    # Execute function under test
    Forklift.MessageHandler.handle_messages([message], %{dataset: dataset})

    # Verify behavior
    assert_receive [{"key_two", msg}]
    assert [] == Jason.decode!(msg)["operational"]["timing"]

    # Verify a data_write_complete event was sent
    assert_event_sent(data_write_complete(), fn event ->
      event.id == dataset.id
    end)

    wait_for_mox()
  end

  defp wait_for_mox do
    SmartCity.TestHelper.eventually(fn ->
      try do
        verify!()
        true
      rescue
        _ -> false
      end
    end)
  end

  defp assert_event_sent(event_type, event_validator) do
    SmartCity.TestHelper.eventually(fn ->
      # The Brook.Test API seems to have changed
      # We'll use a simpler approach to check for events
      Process.info(self(), :messages)
      |> elem(1)
      |> Enum.any?(fn
        {:brook_event, %{type: ^event_type, data: data}} -> event_validator.(data)
        _ -> false
      end)
    end)
  end

  defp timestamp_after?(timestamp_str, %DateTime{} = reference_time) do
    case DateTime.from_iso8601(timestamp_str) do
      {:ok, timestamp, _} -> DateTime.compare(timestamp, reference_time) == :gt
      _ -> false
    end
  end
end
