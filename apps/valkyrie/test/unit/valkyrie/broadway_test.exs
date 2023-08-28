defmodule Valkyrie.BroadwayTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias SmartCity.Data

  import SmartCity.Data, only: [end_of_data: 0]
  import SmartCity.Event, only: [data_standardization_end: 0, event_log_published: 0]
  import SmartCity.TestHelper, only: [eventually: 1]

  @dataset_id "ds1"
  @dataset_id2 "ds2"
  @topic "raw-ds1"
  @producer :ds1_producer
  @current_time "2019-07-17T14:45:06.123456Z"
  @instance_name Valkyrie.instance_name()

  setup do
    allow Elsa.produce(any(), any(), any(), any()), return: :ok
    allow SmartCity.Data.Timing.current_time(), return: @current_time, meck_options: [:passthrough]

    schema = [
      %{name: "name", type: "string", ingestion_field_selector: "name"},
      %{name: "age", type: "integer", ingestion_field_selector: "age"},
      %{name: "alias", type: "string", ingestion_field_selector: "name"}
    ]

    dataset = TDG.create_dataset(id: @dataset_id, technical: %{schema: schema})

    {:ok, broadway} =
      Valkyrie.Broadway.start_link(
        dataset: dataset,
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

  test "should return transformed data", %{broadway: broadway} do
    data = TDG.create_data(dataset_ids: [@dataset_id, @dataset_id2], payload: %{"name" => "johnny", "age" => "21"})
    kafka_message = %{value: Jason.encode!(data)}

    Broadway.test_batch(broadway, [kafka_message])

    assert_receive {:ack, _ref, messages, _}, 5_000

    payloads =
      messages
      |> Enum.map(fn message -> Data.new(message.data.value) end)
      |> Enum.map(fn {:ok, data} -> data end)
      |> Enum.map(fn data -> data.payload end)

    assert payloads == [%{"name" => "johnny", "age" => 21, "alias" => "johnny"}]
  end

  test "should send event log on successful transformation", %{broadway: broadway} do
    ingestion_id = "testIngestionId"

    data =
      TDG.create_data(
        dataset_ids: [@dataset_id, @dataset_id2],
        ingestion_id: ingestion_id,
        payload: %{"name" => "johnny", "age" => "21"}
      )
    end_of_data =
      TDG.create_data(
        dataset_ids: [@dataset_id, @dataset_id2],
        ingestion_id: ingestion_id,
        payload: end_of_data()
      )

    kafka_message = %{value: Jason.encode!(data)}
    eod_message = %{value: Jason.encode!(end_of_data)}

    dateTime = ~U[2023-01-01 00:00:00Z]
    allow(DateTime.utc_now(), return: dateTime)

    first_expected_event_log = %SmartCity.EventLog{
      title: "Validations Complete",
      timestamp: dateTime |> DateTime.to_string(),
      source: "Valkyrie",
      description: "Validations have been completed.",
      ingestion_id: ingestion_id,
      dataset_id: @dataset_id
    }

    second_expected_event_log = %SmartCity.EventLog{
      title: "Validations Complete",
      timestamp: dateTime |> DateTime.to_string(),
      source: "Valkyrie",
      description: "Validations have been completed.",
      ingestion_id: ingestion_id,
      dataset_id: @dataset_id2
    }

    expect(Brook.Event.send(any(), event_log_published(), :valkyrie, first_expected_event_log), return: :ok)
    expect(Brook.Event.send(any(), event_log_published(), :valkyrie, second_expected_event_log), return: :ok)

    Broadway.test_batch(broadway, [kafka_message, eod_message])

    assert_receive {:ack, _ref, messages, _}, 5_000

    payloads =
      messages
      |> Enum.map(fn message -> Data.new(message.data.value) end)
      |> Enum.map(fn {:ok, data} -> data end)
      |> Enum.map(fn data -> data.payload end)

    assert payloads == [%{"name" => "johnny", "age" => 21, "alias" => "johnny"}, end_of_data()]
  end

  test "applies valkyrie message timing", %{broadway: broadway} do
    Application.put_env(:valkyrie, :profiling_enabled, true)
    data = TDG.create_data(dataset_ids: [@dataset_id, @dataset_id2], payload: %{"name" => "johnny", "age" => 21})
    kafka_message = %{value: Jason.encode!(data)}

    Broadway.test_batch(broadway, [kafka_message])

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

  test "should return empty timing when profiling status is not true", %{broadway: broadway} do
    Application.put_env(:valkyrie, :profiling_enabled, false)
    data = TDG.create_data(dataset_ids: [@dataset_id, @dataset_id2], payload: %{"name" => "johnny", "age" => 21})
    kafka_message = %{value: Jason.encode!(data)}

    Broadway.test_batch(broadway, [kafka_message])

    assert_receive {:ack, _ref, messages, _}, 5_000

    timing =
      messages
      |> Enum.map(fn message -> Data.new(message.data.value) end)
      |> Enum.map(fn {:ok, data} -> data.operational.timing end)
      |> List.flatten()
      |> Enum.filter(fn timing -> timing.app == "valkyrie" end)

    assert timing == []
  end

  test "should yeet message when it fails to parse properly", %{broadway: broadway} do
    allow SmartCity.Data.new(any()), return: {:error, :something_went_badly}

    kafka_message = %{value: Jason.encode!(%{payload: %{}, ingestion_id: ""})}

    Broadway.test_batch(broadway, [kafka_message])

    assert_receive {:ack, _ref, _, [message]}, 5_000
    assert {:failed, :something_went_badly} == message.status

    eventually(fn ->
      {:ok, dlqd_message} = DeadLetter.Carrier.Test.receive()
      refute dlqd_message == :empty

      assert dlqd_message.app == "Valkyrie"
      assert dlqd_message.dataset_ids == [@dataset_id]
      assert dlqd_message.reason == ":something_went_badly"
    end)
  end

  test "should yeet message if standardizing data fails due to schmear validation", %{broadway: broadway} do
    data =
      TDG.create_data(dataset_ids: [@dataset_id, @dataset_id2], payload: %{"name" => "johnny", "age" => "twenty-one"})

    kafka_message = %{value: Jason.encode!(data)}

    Broadway.test_batch(broadway, [kafka_message])

    assert_receive {:ack, _ref, _, failed_messages}, 5_000
    assert 1 == length(failed_messages)

    eventually(fn ->
      {:ok, dlqd_message} = DeadLetter.Carrier.Test.receive()
      refute dlqd_message == :empty

      assert dlqd_message.app == "Valkyrie"
      assert dlqd_message.dataset_ids == [@dataset_id]
      assert dlqd_message.reason == "%{\"age\" => :invalid_integer}"
      assert dlqd_message.error == :failed_schema_validation
      assert dlqd_message.original_message == Jason.encode!(data)
    end)
  end

  test "should send the messages to the output kafka topic", %{broadway: broadway} do
    data1 = TDG.create_data(dataset_id: @dataset_id, payload: %{"name" => "johnny", "age" => 21})
    data2 = TDG.create_data(dataset_id: @dataset_id, payload: %{"name" => "carl", "age" => 33})
    end_of_data = TDG.create_data(dataset_id: @dataset_id, payload: end_of_data())

    eod_message = %{value: Jason.encode!(end_of_data)}
    kafka_messages = [%{value: Jason.encode!(data1)}, %{value: Jason.encode!(data2)}, eod_message]

    Broadway.test_batch(broadway, kafka_messages)

    assert_receive {:ack, _ref, messages, _}, 5_000
    assert 3 == length(messages)

    captured_messages = capture(Elsa.produce(:"#{@dataset_id}_producer", :output_topic, any(), partition: 0), 3)

    assert 3 = length(captured_messages)

    assert Enum.at(captured_messages, 0) |> Jason.decode!() |> Map.get("payload") == %{
             "age" => 21,
             "name" => "johnny",
             "alias" => "johnny"
           }

    assert Enum.at(captured_messages, 1) |> Jason.decode!() |> Map.get("payload") == %{
             "age" => 33,
             "name" => "carl",
             "alias" => "carl"
           }
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
