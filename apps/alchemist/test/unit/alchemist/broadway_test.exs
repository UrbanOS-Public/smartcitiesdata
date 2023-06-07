defmodule Alchemist.BroadwayTest do
  use ExUnit.Case
  use Properties, otp_app: :alchemist

  alias SmartCity.TestDataGenerator, as: TDG
  alias SmartCity.Data

  import Mock
  import SmartCity.TestHelper, only: [eventually: 1]

  @ingestion_id "ingestion1"
  @dataset_id "ds1"
  @dataset_id2 "ds2"
  @topic "raw-ds1"
  @producer :ds1_producer
  @current_time "2019-07-17T14:45:06.123456Z"

  getter(:output_topic_prefix, generic: true)

  describe "with valid transformations" do
    setup_with_mocks([
      {Elsa, [], [produce: fn(_, _, _, _) -> :ok end]},
      {SmartCity.Data.Timing, [:passthrough], [current_time: fn() -> @current_time end]}
    ]) do

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
          targetDatasets: [@dataset_id, @dataset_id2],
          transformations: [transform1, transform2]
        })

      {:ok, broadway} =
        Alchemist.Broadway.start_link(
          # ingestion is destructured in handle message as the third argument
          #   it serves as context for an incoming SmartCity.data message
          ingestion: ingestion,
          output: [
            topics: [:output_topic],
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

      [broadway_name: String.to_atom("#{@ingestion_id}_broadway")]
    end

    test "should run with nested lists", %{broadway_name: broadway_name} do
      data =
        TDG.create_data(
          dataset_id: @dataset_id,
          payload: %{
            "phone" => "(555) 8675309",
            "first_name" => "Nicole",
            "string_list" => [["one", "two"], ["three", "four"]],
            "number_list" => [[1, 3], [5, 7]]
          }
        )

      kafka_message = %{value: Jason.encode!(data)}

      Broadway.test_batch(broadway_name, [kafka_message])

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
      assert Map.get(payload, "string_list") == [["one", "two"], ["three", "four"]]
      assert Map.get(payload, "number_list") == [[1, 3], [5, 7]]
    end

    test "should run with nested, nested lists", %{broadway_name: broadway_name} do
      data =
        TDG.create_data(
          dataset_id: @dataset_id,
          payload: %{
            "phone" => "(555) 8675309",
            "first_name" => "Nicole",
            "string_list" => [["one", "two"], ["three", "four"]],
            "parent" => %{
              "number_list" => [[1, 3], [5, 7]]
            }
          }
        )

      kafka_message = %{value: Jason.encode!(data)}

      Broadway.test_batch(broadway_name, [kafka_message])

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
      assert Map.get(payload, "string_list") == [["one", "two"], ["three", "four"]]
      assert payload |> Map.get("parent") |> Map.get("number_list") == [[1, 3], [5, 7]]
    end

    test "given valid transformation ingestion data, should call Regex Extract, pulling out the relevant data", %{
      broadway_name: broadway_name
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

      Broadway.test_batch(broadway_name, [kafka_message])

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

    test "should return empty timing when profiling status is not true", %{broadway_name: broadway_name} do
      Application.put_env(:alchemist, :profiling_enabled, false)
      data = TDG.create_data(dataset_id: @dataset_id, payload: %{"name" => "johnny", "age" => 21})
      kafka_message = %{value: Jason.encode!(data)}

      Broadway.test_batch(broadway_name, [kafka_message])

      assert_receive {:ack, _ref, messages, _}, 5_000

      timing =
        messages
        |> Enum.map(fn message -> Data.new(message.data.value) end)
        |> Enum.map(fn {:ok, data} -> data.operational.timing end)
        |> List.flatten()
        |> Enum.filter(fn timing -> timing.app == "alchemist" end)

      assert timing == []
    end

    test "should send the messages to the output kafka topic", %{broadway_name: broadway_name} do
      data1 =
        TDG.create_data(dataset_id: @dataset_id, payload: %{"phone" => "(555) 555-5555", "first_name" => "johnny"})

      data2 = TDG.create_data(dataset_id: @dataset_id, payload: %{"phone" => "(123) 456-7890", "first_name" => "carl"})
      kafka_messages = [%{value: Jason.encode!(data1)}, %{value: Jason.encode!(data2)}]

      Broadway.test_batch(broadway_name, kafka_messages)

      assert_receive {:ack, _ref, messages, _}, 5_000
      assert 2 == length(messages)

      [{pid, {module, method, calls}, :ok}] = call_history(Elsa)

      assert not is_nil(pid)
      assert module == Elsa
      assert method == :produce
      assert length(calls) == 4
    end

    test "should dead letter messages that don't match the SmartCity.Message struct", %{broadway_name: broadway_name} do
      badData = %{bad_field: "junk"}
      kafka_messages = [%{value: Jason.encode!(badData)}]
      Broadway.test_batch(broadway_name, kafka_messages)

      assert_receive {:ack, _ref, _, [message]}, 5_000
      assert {:failed, "Invalid data message: %{\"bad_field\" => \"junk\"}"} == message.status

      eventually(fn ->
        {:ok, dead_message} = DeadLetter.Carrier.Test.receive()
        refute dead_message == :empty

        assert dead_message.app == "Alchemist"
        assert dead_message.dataset_ids == [@dataset_id, @dataset_id2]
        assert dead_message.original_message == Jason.encode!(badData)
        assert dead_message.reason == inspect("Invalid data message: %{\"bad_field\" => \"junk\"}")
      end)
    end

    test "should dead letter messages that fail to be transformed", %{broadway_name: broadway_name} do
      data1 = TDG.create_data(dataset_ids: [@dataset_id, @dataset_id2], payload: %{"name" => "johnny", "age" => 21})

      kafka_messages = [%{value: Jason.encode!(data1)}]

      Broadway.test_batch(broadway_name, kafka_messages)

      assert_receive {:ack, _ref, _, failed_messages}, 5_000
      assert 1 == length(failed_messages)

      eventually(fn ->
        {:ok, dead_message} = DeadLetter.Carrier.Test.receive()
        refute dead_message == :empty

        assert dead_message.app == "Alchemist"
        assert dead_message.dataset_ids == [@dataset_id, @dataset_id2]
        assert dead_message.original_message == Jason.encode!(data1)
      end)
    end
  end

  describe "with invalid transformation" do
    setup_with_mocks([
      {Elsa, [], [produce: fn(_, _, _, _) -> :ok end]},
      {SmartCity.Data.Timing, [:passthrough], [current_time: fn() -> @current_time end]}
    ]) do

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
          targetDatasets: [@dataset_id, @dataset_id2],
          transformations: [transform]
        })

      {:ok, broadway} =
        Alchemist.Broadway.start_link(
          # ingestion is destructured in handle message as the th~ird argument
          #   it serves as context for an incoming SmartCity.data message
          ingestion: ingestion,
          output: [
            topics: ["#{output_topic_prefix()}-#{@dataset_id}", "#{output_topic_prefix()}-#{@dataset_id2}"],
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

      [broadway_name: String.to_atom("#{@ingestion_id}_broadway")]
    end

    test "should dead letter messages", %{broadway_name: broadway_name} do
      data1 =
        TDG.create_data(
          dataset_ids: [@dataset_id, @dataset_id2],
          payload: %{"phone" => "(555) 555-5555", "first_name" => "johnny"}
        )

      kafka_messages = [%{value: Jason.encode!(data1)}]

      Broadway.test_batch(broadway_name, kafka_messages)

      assert_receive {:ack, _ref, _, failed_messages}, 5_000
      assert 1 == length(failed_messages)

      eventually(fn ->
        {:ok, dead_message} = DeadLetter.Carrier.Test.receive()
        refute dead_message == :empty

        assert dead_message.app == "Alchemist"
        assert dead_message.dataset_ids == [@dataset_id, @dataset_id2]
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
