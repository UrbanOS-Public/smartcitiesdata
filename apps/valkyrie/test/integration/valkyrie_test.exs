defmodule ValkyrieTest do
  use ExUnit.Case
  use Divo
  alias SmartCity.TestDataGenerator, as: TDG

  @endpoints Application.get_env(:valkyrie, :brod_brokers)
  @dlq_topic Application.get_env(:yeet, :topic)
  @output_topic_prefix Application.get_env(:valkyrie, :output_topic_prefix)

  setup_all do
    dataset =
      TDG.create_dataset(%{
        id: "pirates",
        technical: %{
          schema: [
            %{name: "name", type: "string"},
            %{name: "alignment", type: "string"},
            %{name: "age", type: "string"}
          ]
        }
      })

    messages =
      [
        TDG.create_data(%{
          payload: %{name: "Jack Sparrow", alignment: "chaotic", age: "32"},
          dataset_id: dataset.id
        }),
        TDG.create_data(%{
          payload: %{name: "Blackbeard"},
          dataset_id: dataset.id
        }),
        TDG.create_data(%{
          payload: %{name: "Will Turner", alignment: "good", age: "25"},
          dataset_id: dataset.id
        }),
        TDG.create_data(%{
          payload: %{name: "Barbosa", alignment: "evil", age: "100"},
          dataset_id: dataset.id
        })
      ]
      |> Enum.map(&Jason.encode!/1)

    Elsa.Topic.create(@endpoints, "#{@output_topic_prefix}-#{dataset.id}")
    SmartCity.Dataset.write(dataset)

    Patiently.wait_for(
      fn -> Valkyrie.TopicManager.is_topic_ready?("raw-pirates") end,
      dwell: 500,
      max_tries: 100
    )

    SmartCity.KafkaHelper.send_to_kafka(messages, "raw-pirates")

    {:ok, %{dataset: dataset}}
  end

  test "valkyrie updates the operational struct", %{dataset: dataset} do
    Patiently.wait_for!(
      fn ->
        "#{@output_topic_prefix}-#{dataset.id}"
        |> TestHelpers.extract_data_messages(@endpoints)
        |> Enum.any?(fn message ->
          "valkyrie" == message.operational.timing |> hd |> Map.get(:app)
        end)
      end,
      dwell: 1000,
      max_tries: 10
    )
  end

  test "valkyrie does not change the content of the messages processed", %{dataset: dataset} do
    Patiently.wait_for!(
      fn ->
        names =
          "#{@output_topic_prefix}-#{dataset.id}"
          |> TestHelpers.extract_data_messages(@endpoints)
          |> Enum.map(fn message ->
            message.payload.name
          end)

        names == ["Jack Sparrow", "Will Turner", "Barbosa"]
      end,
      dwell: 1000,
      max_tries: 10
    )
  end

  test "valkyrie sends invalid data messages to the dlq" do
    Patiently.wait_for!(
      fn ->
        @dlq_topic
        |> TestHelpers.extract_dlq_messages(@endpoints)
        |> Enum.any?(fn message ->
          String.contains?(message.reason, "The following fields were invalid: alignment, age") &&
            message.app == "Valkyrie" &&
            String.contains?(inspect(message.original_message), "Blackbeard")
        end)
      end,
      dwell: 1000,
      max_tries: 10
    )
  end
end
