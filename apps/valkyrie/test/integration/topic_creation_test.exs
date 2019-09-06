defmodule Valkyrie.TopicCreationTest do
  use ExUnit.Case
  use Divo
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper
  import SmartCity.Event, only: [dataset_extract_start: 0]

  @endpoints Application.get_env(:valkyrie, :elsa_brokers)
  @input_topic_prefix Application.get_env(:valkyrie, :input_topic_prefix)
  @output_topic_prefix Application.get_env(:valkyrie, :output_topic_prefix)

  test "Input and Output topics should be created when a dataset:update event is consumed" do
    dataset_id = Faker.UUID.v4()
    input_topic = "#{@input_topic_prefix}-#{dataset_id}"
    output_topic = "#{@output_topic_prefix}-#{dataset_id}"

    dataset =
      TDG.create_dataset(
        id: dataset_id,
        technical: %{
          schema: [
            %{name: "name", type: "map", subSchema: [%{name: "first", type: "string"}, %{name: "last", type: "string"}]}
          ]
        }
      )

    data_message =
      TestHelpers.create_data(%{
        dataset_id: dataset.id,
        payload: %{"name" => %{"first" => "Ben", "last" => "Brewer"}}
      })

    Brook.Event.send(dataset_extract_start(), :author, dataset)

    TestHelpers.wait_for_topic(@endpoints, input_topic)
    TestHelpers.produce_message(data_message, input_topic, @endpoints)

    eventually fn ->
      messages = TestHelpers.get_data_messages_from_kafka(output_topic, @endpoints)

      assert data_message in messages
    end
  end
end
