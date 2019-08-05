defmodule Valkyrie.BroadwayTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias SmartCity.Data

  @dataset_id "ds1"
  @topic "raw-ds1"
  @producer :ds1_producer
  @current_time "2019-07-17T14:45:06.123456Z"

  setup do
    allow Elsa.produce_sync(any(), any(), any()), return: :ok
    allow SmartCity.Data.Timing.current_time(), return: @current_time, meck_options: [:passthrough]

    schema = [
      %{name: "name", type: "string"},
      %{name: "age", type: "integer"}
    ]

    dataset = TDG.create_dataset(id: @dataset_id, technical: %{schema: schema})

    {:ok, broadway} =
      Valkyrie.Broadway.start_link(dataset: dataset, topics: [@topic], producer: @producer, output_topic: :output_topic)

    on_exit(fn ->
      ref = Process.monitor(broadway)
      Process.exit(broadway, :normal)
      assert_receive {:DOWN, ^ref, _, _, _}, 2_000
    end)

    [broadway: broadway]
  end

  test "should return transformed data", %{broadway: broadway} do
    data = TDG.create_data(dataset_id: @dataset_id, payload: %{"name" => "johnny", "age" => "21"})
    kafka_message = %{value: Jason.encode!(data)}

    Broadway.test_messages(broadway, [kafka_message])

    assert_receive {:ack, _ref, messages, _}, 5_000

    payloads =
      messages
      |> Enum.map(fn message -> Data.new(message.data.value) end)
      |> Enum.map(fn {:ok, data} -> data end)
      |> Enum.map(fn data -> data.payload end)

    assert payloads == [%{"name" => "johnny", "age" => 21}]
  end

  test "applies valkyrie message timing", %{broadway: broadway} do
    data = TDG.create_data(dataset_id: @dataset_id, payload: %{"name" => "johnny", "age" => 21})
    kafka_message = %{value: Jason.encode!(data)}

    Broadway.test_messages(broadway, [kafka_message])

    assert_receive {:ack, _ref, messages, _}, 5_000

    timing =
      messages
      |> Enum.map(fn message -> Data.new(message.data.value) end)
      |> Enum.map(fn {:ok, data} -> data.operational.timing end)
      |> List.flatten()
      |> Enum.filter(fn timing -> timing.app == "valkyrie" end)

    assert timing == [
             %SmartCity.Data.Timing{
               app: "valkyrie",
               end_time: @current_time,
               label: "timing",
               start_time: @current_time
             }
           ]
  end

  test "should yeet message when it fails to parse properly", %{broadway: broadway} do
    allow SmartCity.Data.new(any()), return: {:error, :something_went_badly}
    allow Yeet.process_dead_letter(any(), any(), any(), any()), return: :ok

    kafka_message = %{value: :message}

    Broadway.test_messages(broadway, [kafka_message])

    assert_receive {:ack, _ref, _, [message]}, 5_000
    assert {:failed, :something_went_badly} == message.status

    assert_called Yeet.process_dead_letter(@dataset_id, :message, "Valkyrie", reason: :something_went_badly)
  end

  test "should yeet message is standardizing data fails do to schmea validation", %{broadway: broadway} do
    allow Yeet.process_dead_letter(any(), any(), any(), any()), return: :ok

    data = TDG.create_data(dataset_id: @dataset_id, payload: %{"name" => "johnny", "age" => "twenty-one"})
    kafka_message = %{value: Jason.encode!(data)}

    Broadway.test_messages(broadway, [kafka_message])

    assert_receive {:ack, _ref, _, failed_messages}, 5_000
    assert 1 == length(failed_messages)

    assert_called Yeet.process_dead_letter("ds1", Jason.encode!(data), "Valkyrie",
                    error: :failed_schema_validation,
                    reason: %{"age" => :invalid_integer}
                  )
  end

  test "should send the messages to the output kafka topic", %{broadway: broadway} do
    data1 = TDG.create_data(dataset_id: @dataset_id, payload: %{"name" => "johnny", "age" => 21})
    data2 = TDG.create_data(dataset_id: @dataset_id, payload: %{"name" => "carl", "age" => 33})
    kafka_messages = [%{value: Jason.encode!(data1)}, %{value: Jason.encode!(data2)}]

    Broadway.test_messages(broadway, kafka_messages)

    assert_receive {:ack, _ref, messages, _}, 5_000
    assert 2 == length(messages)

    captured_messages =
      capture(Elsa.produce_sync(:output_topic, any(), partition: 0, name: :"#{@dataset_id}_producer"), 2)

    assert 2 = length(captured_messages)
    assert Enum.at(captured_messages, 0) |> Jason.decode!() |> Map.get("payload") == data1.payload
    assert Enum.at(captured_messages, 1) |> Jason.decode!() |> Map.get("payload") == data2.payload
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
