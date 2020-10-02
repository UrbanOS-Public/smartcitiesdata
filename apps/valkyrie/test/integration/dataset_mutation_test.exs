defmodule Valkyrie.DatasetMutationTest do
  use ExUnit.Case
  import SmartCity.TestHelper
  import SmartCity.Event, only: [data_ingest_start: 0, dataset_delete: 0]
  alias SmartCity.TestDataGenerator, as: TDG

  alias Valkyrie.TopicHelper

  @endpoints Application.get_env(:valkyrie, :elsa_brokers)

  @tag timeout: 120_000
  test "a dataset with an updated schema properly parses new messages" do
    schema = [%{name: "age", type: "string"}]
    dataset = TDG.create_dataset(technical: %{schema: schema})
    input_topic = TopicHelper.input_topic_name(dataset.id)
    output_topic = TopicHelper.output_topic_name(dataset.id)

    data = TDG.create_data(dataset_id: dataset.id, payload: %{"age" => "21"})

    Brook.Event.send(@instance, data_ingest_start(), :author, dataset)
    Testing.Kafka.wait_for_topic(@endpoints, input_topic)
    Testing.Kafka.wait_for_topic(@endpoints, output_topic)

    Testing.Kafka.produce_messages([data], input_topic, @endpoints)

    eventually(
      fn ->
        messages = Testing.SmartCity.Data.fetch_data_messages(@endpoints, output_topic)

        payloads =
          Enum.map(messages, fn message -> SmartCity.Data.new(message.value) |> elem(1) |> Map.get(:payload) end)

        assert payloads == [%{"age" => "21"}]
      end,
      2_000,
      40
    )

    updated_dataset = %{dataset | technical: %{dataset.technical | schema: [%{name: "age", type: "integer"}]}}
    Brook.Event.send(@instance, data_ingest_start(), :author, updated_dataset)

    Process.sleep(2_000)

    data2 = TDG.create_data(dataset_id: @dataset_id, payload: %{"age" => "22"})
    Elsa.produce(@endpoints, @input_topic, Jason.encode!(data2), partition: 0)

    eventually(
      fn ->
        messages = Elsa.Fetch.fetch_stream(@endpoints, @output_topic) |> Enum.into([])

        payloads =
          Enum.map(messages, fn message -> SmartCity.Data.new(message.value) |> elem(1) |> Map.get(:payload) end)

        assert payloads == [%{"age" => "21"}, %{"age" => 22}]
      end,
      2_000,
      10
    )
  end

  test "should delete all view state for the dataset and the input and output topics when dataset:delete is called" do
    dataset_id = Faker.UUID.v4()
    input_topic = "#{@input_topic_prefix}-#{dataset_id}"
    output_topic = "#{@output_topic_prefix}-#{dataset_id}"
    dataset = TDG.create_dataset(id: dataset_id, technical: %{sourceType: "ingest"})

    Brook.Event.send(@instance, data_ingest_start(), :author, dataset)

    eventually(
      fn ->
        assert true == is_dataset_supervisor_alive(dataset_id)
        assert {:ok, dataset} == Brook.ViewState.get(@instance, :datasets, dataset_id)
        assert true == Elsa.Topic.exists?(@endpoints, input_topic)
        assert true == Elsa.Topic.exists?(@endpoints, output_topic)
      end,
      2_000,
      10
    )

    Brook.Event.send(@instance, dataset_delete(), :author, dataset)

    eventually(
      fn ->
        assert false == is_dataset_supervisor_alive(dataset_id)
        assert {:ok, nil} == Brook.ViewState.get(@instance, :datasets, dataset_id)
        assert false == Elsa.Topic.exists?(@endpoints, input_topic)
        assert false == Elsa.Topic.exists?(@endpoints, output_topic)
      end,
      2_000,
      10
    )
  end

  defp is_dataset_supervisor_alive(dataset_id) do
    name = Valkyrie.DatasetSupervisor.name(dataset_id)

    case Process.whereis(name) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end
end
