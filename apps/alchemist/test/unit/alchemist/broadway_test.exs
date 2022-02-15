defmodule Alchemist.BroadwayTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias SmartCity.Data

  import SmartCity.Data, only: [end_of_data: 0]
  import SmartCity.Event, only: [data_standardization_end: 0]
  import SmartCity.TestHelper, only: [eventually: 1]

  @ingestion_id "ingestion1"
  @dataset_id "ds1"
  @topic "raw-ds1"
  @producer :ds1_producer
  @current_time "2019-07-17T14:45:06.123456Z"
  @instance_name Alchemist.instance_name()

  setup do
    allow Elsa.produce(any(), any(), any(), any()), return: :ok
    allow SmartCity.Data.Timing.current_time(), return: @current_time, meck_options: [:passthrough]

    ingestion = TDG.create_ingestion(%{id: @ingestion_id})

    {:ok, broadway} =
      Alchemist.Broadway.start_link(
        ingestion: ingestion,
        output: [
          topic: :output_topic,
          connection: @producer
        ],
        input: [
          topics: [@topic]
        ]
      )

    on_exit(fn ->
      ref = Process.monitor(broadway)
      Process.exit(broadway, :normal)
      assert_receive {:DOWN, ^ref, _, _, _}, 2_000
    end)

    [broadway: broadway]
  end

  test "should call Transformers.NoOp with the provided data and return its result", %{broadway: broadway} do
    data = TDG.create_data(dataset_id: @dataset_id, payload: %{"name" => "johnny", "age" => "21"})
    kafka_message = %{value: Jason.encode!(data)}

    Broadway.test_batch(broadway, [kafka_message])

    assert_receive {:ack, _ref, messages, _}, 5_000

    payloads =
      messages
      |> Enum.map(fn message -> Data.new(message.data.value) end)
      |> Enum.map(fn {:ok, data} -> data end)
      |> Enum.map(fn data -> data.payload end)

    assert payloads == [%{"name" => "johnny", "age" => "21"}]
  end

  test "should return empty timing when profiling status is not true", %{broadway: broadway} do
    Application.put_env(:alchemist, :profiling_enabled, false)
    data = TDG.create_data(dataset_id: @dataset_id, payload: %{"name" => "johnny", "age" => 21})
    kafka_message = %{value: Jason.encode!(data)}

    Broadway.test_batch(broadway, [kafka_message])

    assert_receive {:ack, _ref, messages, _}, 5_000

    timing =
      messages
      |> Enum.map(fn message -> Data.new(message.data.value) end)
      |> Enum.map(fn {:ok, data} -> data.operational.timing end)
      |> List.flatten()
      |> Enum.filter(fn timing -> timing.app == "alchemist" end)

    assert timing == []
  end

  test "should send the messages to the output kafka topic", %{broadway: broadway} do
    data1 = TDG.create_data(dataset_id: @dataset_id, payload: %{"name" => "johnny", "age" => 21})
    data2 = TDG.create_data(dataset_id: @dataset_id, payload: %{"name" => "carl", "age" => 33})
    kafka_messages = [%{value: Jason.encode!(data1)}, %{value: Jason.encode!(data2)}]

    Broadway.test_batch(broadway, kafka_messages)

    assert_receive {:ack, _ref, messages, _}, 5_000
    assert 2 == length(messages)

    captured_messages = capture(Elsa.produce(:"#{@dataset_id}_producer", :output_topic, any(), partition: 0), 3)

    assert 2 = length(captured_messages)
    assert Enum.at(captured_messages, 0) |> Jason.decode!() |> Map.get("payload") == data1.payload
    assert Enum.at(captured_messages, 1) |> Jason.decode!() |> Map.get("payload") == data2.payload
  end

  test "should not send messages that don't match the SmartCity.Message struct", %{broadway: broadway} do
    badData = %{bad_field: "junk"}
    kafka_messages = [%{value: Jason.encode!(badData)}]
    Broadway.test_batch(broadway, kafka_messages)

    assert_receive {:ack, _ref, _, [message]}, 5_000
    assert {:failed, "Invalid data message: %{\"bad_field\" => \"junk\"}"} == message.status

    # TODO: assert that dlq stuff happens with the message fails
  end
end

defmodule Fake.Producer do
  use GenStage

  def start_link([]) do
    GenStage.start_link(__MODULE__, [])
  end

  def init(_args) do
    {:producer, []}
  end

  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  def handle_events(events, _from, state) do
    {:noreply, events, state}
  end
end
