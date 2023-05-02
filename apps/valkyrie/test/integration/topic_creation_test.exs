defmodule Valkyrie.TopicCreationTest do
  use ExUnit.Case
  use Divo
  use Properties, otp_app: :valkyrie

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper
  import SmartCity.Event, only: [data_ingest_start: 0, dataset_update: 0]

  @instance_name Valkyrie.instance_name()

  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)
  getter(:output_topic_prefix, generic: true)

  test "Input and Output topics should be created when a dataset:update event is consumed" do
    dataset_id = Faker.UUID.v4()
    input_topic = "#{input_topic_prefix()}-#{dataset_id}"
    output_topic = "#{output_topic_prefix()}-#{dataset_id}"

    dataset =
      TDG.create_dataset(
        id: dataset_id,
        technical: %{
          schema: [
            %{name: "name", type: "map", subSchema: [%{name: "first", type: "string", ingestion_field_selector: "first"}, %{name: "last", type: "string", ingestion_field_selector: "last"}], ingestion_field_selector: "name"}
          ]
        }
      )

    ingestion = TDG.create_ingestion(%{targetDataset: dataset.id})

    Brook.Event.send(@instance_name, dataset_update(), :author, dataset)

    eventually fn ->
      assert Brook.get!(@instance_name, :datasets, dataset.id) != nil
    end

    data_message =
      TestHelpers.create_data(%{
        dataset_id: dataset.id,
        payload: %{"name" => %{"first" => "Ben", "last" => "Brewer"}}
      })

    Brook.Event.send(@instance_name, data_ingest_start(), :author, ingestion)

    TestHelpers.wait_for_topic(elsa_brokers(), input_topic)
    TestHelpers.produce_message(data_message, input_topic, elsa_brokers())

    eventually fn ->
      messages = TestHelpers.get_data_messages_from_kafka(output_topic, elsa_brokers())

      assert data_message in messages
    end
  end
end
