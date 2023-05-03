defmodule Valkyrie.EndOfDataTest do
  use ExUnit.Case
  use Divo
  use Properties, otp_app: :valkyrie

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper
  import SmartCity.Event, only: [data_ingest_start: 0, data_standardization_end: 0, dataset_update: 0]
  import SmartCity.Data, only: [end_of_data: 0]

  @instance_name Valkyrie.instance_name()

  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)
  getter(:output_topic_prefix, generic: true)

  test "Data is not processed after END_OF_DATA message" do
    dataset_id = Faker.UUID.v4()

    input_topic = "#{input_topic_prefix()}-#{dataset_id}"
    output_topic = "#{output_topic_prefix()}-#{dataset_id}"

    dataset =
      TDG.create_dataset(
        id: dataset_id,
        technical: %{
          schema: [
            %{
              name: "name",
              type: "map",
              subSchema: [
                %{name: "first", type: "string", ingestion_field_selector: "first"},
                %{name: "last", type: "string", ingestion_field_selector: "last"}
              ],
              ingestion_field_selector: "name"
            }
          ]
        }
      )

    ingestion = TDG.create_ingestion(%{targetDataset: dataset.id})

    data_message =
      TestHelpers.create_data(%{
        dataset_id: dataset.id,
        payload: %{"name" => %{"first" => "Ben", "last" => "Brewer"}}
      })

    eod_message = end_of_data()

    message_to_not_consume =
      TestHelpers.create_data(%{dataset_id: dataset.id, payload: %{"name" => %{"first" => "Post", "last" => "Man"}}})

    Brook.Event.send(@instance_name, dataset_update(), :author, dataset)
    Brook.Event.send(@instance_name, data_ingest_start(), :author, ingestion)

    TestHelpers.wait_for_topic(elsa_brokers(), input_topic)

    TestHelpers.produce_message(data_message, input_topic, elsa_brokers())
    Elsa.Producer.produce(elsa_brokers(), input_topic, {"jerks", eod_message}, parition: 0)

    Patiently.wait_for!(
      fn ->
        data_standarization_end_event_fired("event-stream", elsa_brokers()) &&
          dataset_supervisor_killed(dataset_id)
      end,
      dwell: 1000,
      max_tries: 20
    )

    TestHelpers.produce_message(message_to_not_consume, input_topic, elsa_brokers())

    eventually fn ->
      messages = TestHelpers.get_data_messages_from_kafka(output_topic, elsa_brokers())

      assert messages == [data_message, eod_message]
    end
  end

  def data_standarization_end_event_fired(topic, endpoints) do
    case :brod.fetch(endpoints, topic, 0, 0) do
      {:ok, {_offset, messages}} ->
        messages
        |> Enum.any?(fn message -> elem(message, 2) == data_standardization_end() end)

      _ ->
        false
    end
  end

  def dataset_supervisor_killed(dataset_id) do
    name = Valkyrie.DatasetSupervisor.name(dataset_id)

    case Process.whereis(name) do
      nil -> true
      pid -> Process.alive?(pid) == false
    end
  end
end
