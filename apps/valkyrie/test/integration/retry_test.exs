defmodule Valkyrie.RetryTest do
  use ExUnit.Case
  use Divo
  alias SmartCity.TestDataGenerator, as: TDG

  @endpoints Application.get_env(:valkyrie, :brod_brokers)
  @dlq_topic Application.get_env(:yeet, :topic)
  @input_topic_prefix Application.get_env(:valkyrie, :input_topic_prefix)
  @output_topic_prefix Application.get_env(:valkyrie, :output_topic_prefix)

  test "if handler can't immediately find the receiving topic, it retries up to its configured limit" do
    dataset_id = "missing_topic"
    input_topic = "#{@input_topic_prefix}-#{dataset_id}"
    expected_output_topic = "#{@output_topic_prefix}-#{dataset_id}"

    dataset =
      TDG.create_dataset(
        id: dataset_id,
        technical: %{
          schema: [
            %{name: "name", type: "map", subSchema: [%{name: "first", type: "string"}, %{name: "last", type: "string"}]}
          ]
        }
      )

    original_message =
      %{
        dataset_id: dataset_id,
        payload: %{name: %{first: "Ben", last: "Brewer"}}
      }
      |> TDG.create_data()
      |> TestHelpers.clear_timing()


    Valkyrie.DatasetHandler.handle_dataset(dataset)
    Patiently.wait_for!(
      fn ->
        Valkyrie.TopicManager.is_topic_ready?(input_topic)
      end,
      dwell: 200,
      max_tries: 20
    )

    Elsa.Producer.produce_sync(
      @endpoints,
      input_topic,
      0,
      "jerks",
      Jason.encode!(original_message)
    )

    Process.sleep(2_000)
    Elsa.Topic.create(@endpoints, expected_output_topic)

    Patiently.wait_for!(
      fn ->
        expected_output_topic
        |> TestHelpers.extract_data_messages(@endpoints)
        |> Enum.map(&TestHelpers.clear_timing/1)
        |> Enum.any?(fn message ->
          message == original_message
        end)
      end,
      dwell: 2_000,
      max_tries: 20
    )
  end

  test "if handler can't find the receiving topic, it DLQs the message after all retries" do
    dataset_id = "missing_topic_eternal"
    input_topic = "#{@input_topic_prefix}-#{dataset_id}"

    dataset =
      TDG.create_dataset(
        id: dataset_id,
        technical: %{
          schema: [
            %{name: "name", type: "map", subSchema: [%{name: "first", type: "string"}, %{name: "last", type: "string"}]}
          ]
        }
      )

    original_message =
      TDG.create_data(%{
        dataset_id: dataset_id,
        payload: %{name: %{first: "Brian", last: "Balser"}}
      })

    Valkyrie.DatasetHandler.handle_dataset(dataset)

    Patiently.wait_for!(
      fn ->
        Valkyrie.TopicManager.is_topic_ready?(input_topic)
      end,
      dwell: 200,
      max_tries: 20
    )

    Elsa.Producer.produce_sync(
      @endpoints,
      input_topic,
      0,
      "jerks",
      Jason.encode!(original_message)
    )

    Patiently.wait_for!(
      fn ->
        @dlq_topic
        |> TestHelpers.extract_dlq_messages(@endpoints)
        |> Enum.any?(fn message ->
          message.app == "Valkyrie" &&
            String.contains?(message.original_message, "Brian")
        end)
      end,
      dwell: 5000,
      max_tries: 10
    )
  end
end
