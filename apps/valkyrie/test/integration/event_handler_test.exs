defmodule Valkyrie.EventHandlerTest do
  use ExUnit.Case
  import SmartCity.TestHelper
  import SmartCity.Event, only: [data_ingest_start: 0, dataset_delete: 0]
  alias SmartCity.TestDataGenerator, as: TDG

  alias Valkyrie.TopicHelper

  @endpoints Application.get_env(:valkyrie, :endpoints)

  @tag timeout: 120_000
  test "a dataset with an updated schema properly parses new messages" do
    schema = [%{name: "age", type: "string"}]
    dataset = TDG.create_dataset(technical: %{schema: schema})
    input_topic = TopicHelper.input_topic_name(dataset.id)
    output_topic = TopicHelper.output_topic_name(dataset.id)

    first_data_message = TDG.create_data(dataset_id: dataset.id, payload: %{"age" => "21"})

    Brook.Event.send(:valkyrie, data_ingest_start(), :author, dataset)
    Testing.Kafka.wait_for_topic(@endpoints, input_topic)
    Testing.Kafka.wait_for_topic(@endpoints, output_topic)

    Testing.Kafka.produce_messages([first_data_message], input_topic, @endpoints)

    eventually(
      fn ->
        payloads = Testing.Kafka.fetch_messages(output_topic, @endpoints, SmartCity.Data)
        |> Enum.map(&Map.get(&1, :payload))

        assert payloads == [%{"age" => "21"}]
      end,
      2_000,
      40
    )

    updated_dataset = %{dataset | technical: %{dataset.technical | schema: [%{name: "age", type: "integer"}]}}
    Brook.Event.send(:valkyrie, data_ingest_start(), :author, updated_dataset)

    Process.sleep(2_000)

    second_data_message = TDG.create_data(dataset_id: dataset.id, payload: %{"age" => "22"})
    Testing.Kafka.produce_messages([second_data_message], input_topic, @endpoints)

    eventually(
      fn ->
        payloads = Testing.Kafka.fetch_messages(output_topic, @endpoints, SmartCity.Data)
        |> Enum.map(&Map.get(&1, :payload))

        assert payloads == [%{"age" => 22}]
      end,
      2_000,
      10
    )
  end

  test "should delete all view state for the dataset and the input and output topics when dataset:delete is called" do
    dataset = TDG.create_dataset(technical: %{sourceType: "ingest"})
    input_topic = TopicHelper.input_topic_name(dataset.id)
    output_topic = TopicHelper.output_topic_name(dataset.id)

    Brook.Event.send(:valkyrie, data_ingest_start(), :author, dataset)

    eventually(
      fn ->
        assert is_dataset_supervisor_alive?(dataset.id)
        assert {:ok, _} = Brook.ViewState.get(:valkyrie, :datasets_by_id, dataset.id)
        assert Elsa.Topic.exists?(@endpoints, input_topic)
        assert Elsa.Topic.exists?(@endpoints, output_topic)
      end,
      2_000,
      10
    )

    Brook.Event.send(:valkyrie, dataset_delete(), :author, dataset)

    eventually(
      fn ->
        assert not is_dataset_supervisor_alive?(dataset.id)
        assert {:ok, nil} == Brook.ViewState.get(:valkyrie, :datasets_by_id, dataset.id)
        assert not Elsa.Topic.exists?(@endpoints, input_topic)
        assert not Elsa.Topic.exists?(@endpoints, output_topic)
      end,
      2_000,
      10
    )
  end

  defp is_dataset_supervisor_alive?(dataset_id) do
    case Valkyrie.Stream.Registry.whereis(dataset_id) do
      nil -> false
      :undefined -> false
      pid -> Process.alive?(pid)
    end
  end
end
