defmodule Valkyrie.DatasetMutationTest do
  use ExUnit.Case
  use Divo
  use Properties, otp_app: :valkyrie

  import SmartCity.TestHelper
  import SmartCity.Event, only: [data_ingest_start: 0, dataset_delete: 0, dataset_update: 0]
  alias SmartCity.TestDataGenerator, as: TDG

  @instance_name Valkyrie.instance_name()

  getter(:input_topic_prefix, generic: true)
  getter(:output_topic_prefix, generic: true)
  getter(:elsa_brokers, generic: true)

  @tag timeout: 120_000
  test "a dataset with an updated schema properly parses new messages" do
    dataset_id = Faker.UUID.v4()
    schema = [%{name: "age", type: "string", ingestion_field_selector: "age"}]
    dataset = TDG.create_dataset(id: dataset_id, technical: %{schema: schema})
    ingestion = TDG.create_ingestion(%{targetDataset: dataset_id})

    data1 = TDG.create_data(dataset_id: dataset_id, payload: %{"age" => "21"})
    Brook.Event.send(@instance_name, dataset_update(), :author, dataset)
    Brook.Event.send(@instance_name, data_ingest_start(), :author, ingestion)
    TestHelpers.wait_for_topic(elsa_brokers(), input_topic(dataset_id))
    TestHelpers.wait_for_topic(elsa_brokers(), output_topic(dataset_id))

    Elsa.produce(elsa_brokers(), input_topic(dataset_id), Jason.encode!(data1), partition: 0)

    eventually(
      fn ->
        messages = Elsa.Fetch.fetch_stream(elsa_brokers(), output_topic(dataset_id)) |> Enum.into([])

        payloads =
          Enum.map(messages, fn message -> SmartCity.Data.new(message.value) |> elem(1) |> Map.get(:payload) end)

        assert payloads == [%{"age" => "21"}]
      end,
      2_000,
      40
    )

    updated_dataset = %{
      dataset
      | technical: %{dataset.technical | schema: [%{name: "age", type: "integer", ingestion_field_selector: "age"}]}
    }

    Brook.Event.send(@instance_name, dataset_update(), :author, updated_dataset)

    Process.sleep(2_000)

    data2 = TDG.create_data(dataset_id: dataset_id, payload: %{"age" => "22"})
    Elsa.produce(elsa_brokers(), input_topic(dataset_id), Jason.encode!(data2), partition: 0)

    eventually(
      fn ->
        messages = Elsa.Fetch.fetch_stream(elsa_brokers(), output_topic(dataset_id)) |> Enum.into([])

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
    input_topic = input_topic(dataset_id)
    output_topic = output_topic(dataset_id)
    dataset = TDG.create_dataset(id: dataset_id, technical: %{sourceType: "ingest"})
    ingestion = TDG.create_ingestion(%{targetDataset: dataset.id})
    Brook.Event.send(@instance_name, dataset_update(), :author, dataset)
    Brook.Event.send(@instance_name, data_ingest_start(), :author, ingestion)

    eventually(
      fn ->
        assert true == is_dataset_supervisor_alive(dataset_id)
        assert {:ok, dataset} == Brook.ViewState.get(@instance_name, :datasets, dataset_id)
        assert true == Elsa.Topic.exists?(elsa_brokers(), input_topic)
        assert true == Elsa.Topic.exists?(elsa_brokers(), output_topic)
      end,
      2_000,
      10
    )

    Brook.Event.send(@instance_name, dataset_delete(), :author, dataset)

    eventually(
      fn ->
        assert false == is_dataset_supervisor_alive(dataset_id)
        assert {:ok, nil} == Brook.ViewState.get(@instance_name, :datasets, dataset_id)
        assert false == Elsa.Topic.exists?(elsa_brokers(), input_topic)
        assert false == Elsa.Topic.exists?(elsa_brokers(), output_topic)
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

  defp output_topic(dataset_id), do: "#{output_topic_prefix()}-#{dataset_id}"
  defp input_topic(dataset_id), do: "#{input_topic_prefix()}-#{dataset_id}"
end
