defmodule Alchemist.BroadwayTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias SmartCity.Data

  import SmartCity.TestHelper, only: [eventually: 1]

  @ingestion_id "ingestion1"
  @dataset_id "ds1"
  @topic "raw-ds1"
  @producer :ds1_producer
  @current_time "2019-07-17T14:45:06.123456Z"

  describe "with valid transformations" do
    setup do
      allow Elsa.produce(any(), any(), any(), any()), return: :ok
      allow SmartCity.Data.Timing.current_time(), return: @current_time, meck_options: [:passthrough]

      transform1 =
        TDG.create_transformation(%{
          type: "regex_extract",
          parameters: %{
            "sourceField" => "phone",
            "targetField" => "area_code",
            "regex" => "\\((\\d{3})\\)"
          }
        })

      transform2 =
        TDG.create_transformation(%{
          type: "regex_extract",
          parameters: %{
            sourceField: "first_name",
            targetField: "first_letter",
            regex: "^(\\w)"
          }
        })

      ingestion =
        TDG.create_ingestion(%{
          id: @ingestion_id,
          targetDataset: @dataset_id,
          transformations: [transform1, transform2]
        })

      {:ok, broadway} =
        Alchemist.Broadway.start_link(
          # ingestion is destructured in handle message as the th~ird argument
          #   it serves as context for an incoming SmartCity.data message
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

    test "given valid transformation ingestion data, should call Regex Extract, pulling out the relevant data", %{
      broadway: broadway
    } do
      data =
        TDG.create_data(
          dataset_id: @dataset_id,
          payload: %{
            "phone" => "(555) 8675309",
            "first_name" => "Nicole"
          }
        )

      kafka_message = %{value: Jason.encode!(data)}

      Broadway.test_batch(broadway, [kafka_message])

      assert_receive {:ack, _ref, messages, _}, 5_000

      assert 1 == length(messages)

      payload =
        messages
        |> Enum.map(fn message -> Data.new(message.data.value) end)
        |> Enum.map(fn {:ok, data} -> data end)
        |> Enum.map(fn data -> data.payload end)
        |> List.first()

      assert Map.get(payload, "phone") == "(555) 8675309"
      assert Map.get(payload, "area_code") == "555"
      assert Map.get(payload, "first_name") == "Nicole"
      assert Map.get(payload, "first_letter") == "N"
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
      data1 =
        TDG.create_data(dataset_id: @dataset_id, payload: %{"phone" => "(555) 555-5555", "first_name" => "johnny"})

      data2 = TDG.create_data(dataset_id: @dataset_id, payload: %{"phone" => "(123) 456-7890", "first_name" => "carl"})
      kafka_messages = [%{value: Jason.encode!(data1)}, %{value: Jason.encode!(data2)}]

      Broadway.test_batch(broadway, kafka_messages)

      assert_receive {:ack, _ref, messages, _}, 5_000
      assert 2 == length(messages)

      captured_messages = capture(Elsa.produce(:"#{@dataset_id}_producer", :output_topic, any(), partition: 0), 3)

      assert 2 = length(captured_messages)
    end

    test "should dead letter messages that don't match the SmartCity.Message struct", %{broadway: broadway} do
      badData = %{bad_field: "junk"}
      kafka_messages = [%{value: Jason.encode!(badData)}]
      Broadway.test_batch(broadway, kafka_messages)

      assert_receive {:ack, _ref, _, [message]}, 5_000
      assert {:failed, "Invalid data message: %{\"bad_field\" => \"junk\"}"} == message.status

      eventually(fn ->
        {:ok, dead_message} = DeadLetter.Carrier.Test.receive()
        refute dead_message == :empty

        assert dead_message.app == "Alchemist"
        assert dead_message.dataset_id == @dataset_id
        assert dead_message.original_message == Jason.encode!(badData)
        assert dead_message.reason == "Invalid data message: %{\"bad_field\" => \"junk\"}"
      end)
    end

    test "should dead letter messages that fail to be transformed", %{broadway: broadway} do
      data1 = TDG.create_data(dataset_id: @dataset_id, payload: %{"name" => "johnny", "age" => 21})

      kafka_messages = [%{value: Jason.encode!(data1)}]

      Broadway.test_batch(broadway, kafka_messages)

      assert_receive {:ack, _ref, _, failed_messages}, 5_000
      assert 1 == length(failed_messages)

      eventually(fn ->
        {:ok, dead_message} = DeadLetter.Carrier.Test.receive()
        refute dead_message == :empty

        assert dead_message.app == "Alchemist"
        assert dead_message.dataset_id == "ds1"
        assert dead_message.original_message == Jason.encode!(data1)
      end)
    end
  end

  describe "with invalid transformation" do
    setup do
      allow Elsa.produce(any(), any(), any(), any()), return: :ok
      allow SmartCity.Data.Timing.current_time(), return: @current_time, meck_options: [:passthrough]

      transform =
        TDG.create_transformation(%{
          type: "regex_extract",
          parameters: %{
            :sourceField => "phone",
            :targetField => "area_code",
            :regex => "^\((\d{3})"
          }
        })

      ingestion =
        TDG.create_ingestion(%{
          id: @ingestion_id,
          targetDataset: @dataset_id,
          transformations: [transform]
        })

      {:ok, broadway} =
        Alchemist.Broadway.start_link(
          # ingestion is destructured in handle message as the th~ird argument
          #   it serves as context for an incoming SmartCity.data message
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

    test "should dead letter messages", %{broadway: broadway} do
      data1 =
        TDG.create_data(dataset_id: @dataset_id, payload: %{"phone" => "(555) 555-5555", "first_name" => "johnny"})

      kafka_messages = [%{value: Jason.encode!(data1)}]

      Broadway.test_batch(broadway, kafka_messages)

      assert_receive {:ack, _ref, _, failed_messages}, 5_000
      assert 1 == length(failed_messages)

      eventually(fn ->
        {:ok, dead_message} = DeadLetter.Carrier.Test.receive()
        refute dead_message == :empty

        assert dead_message.app == "Alchemist"
        assert dead_message.dataset_id == "ds1"
        assert dead_message.original_message == Jason.encode!(data1)
      end)
    end
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
