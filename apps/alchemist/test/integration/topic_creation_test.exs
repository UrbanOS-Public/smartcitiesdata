defmodule Alchemist.TopicCreationTest do
  use ExUnit.Case
  use Divo
  use Properties, otp_app: :alchemist

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper
  import SmartCity.Event, only: [ingestion_update: 0]

  @instance_name Alchemist.instance_name()

  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)
  getter(:output_topic_prefix, generic: true)

  test "Input and Output topics should be created when a ingestion_update event is consumed" do
    ingestion_id = Faker.UUID.v4()
    dataset_id = Faker.UUID.v4()
    dataset_id2 = Faker.UUID.v4()
    input_topic = "#{input_topic_prefix()}-#{ingestion_id}"

    output_topic_1 = "#{output_topic_prefix()}-#{dataset_id}"
    output_topic_2 = "#{output_topic_prefix()}-#{dataset_id2}"

    ingestion = TDG.create_ingestion(%{id: ingestion_id, targetDatasets: [dataset_id, dataset_id2]})

    data_message =
      TestHelpers.create_data(%{
        dataset_ids: [dataset_id, dataset_id2],
        payload: %{"name" => %{"first" => "Ben", "last" => "Brewer"}}
      })

    Brook.Event.send(@instance_name, ingestion_update(), :author, ingestion)

    TestHelpers.wait_for_topic(elsa_brokers(), input_topic)
    TestHelpers.produce_message(data_message, input_topic, elsa_brokers())

    eventually fn ->
      first_output_topic_messages = TestHelpers.get_data_messages_from_kafka(output_topic_1, elsa_brokers())
      second_output_topic_messages = TestHelpers.get_data_messages_from_kafka(output_topic_2, elsa_brokers())

      assert data_message in first_output_topic_messages
      assert data_message in second_output_topic_messages
    end
  end
end
