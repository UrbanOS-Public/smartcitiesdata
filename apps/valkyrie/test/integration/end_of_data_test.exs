defmodule Valkyrie.EndOfDataTest do
  use ExUnit.Case
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper

  import SmartCity.Event, only: [data_ingest_start: 0, data_standardization_end: 0]
  import SmartCity.Data, only: [end_of_data: 0]

  alias Valkyrie.TopicHelper

  @endpoints Application.get_env(:valkyrie, :endpoints)

  setup_all do
    Application.put_env(:valkyrie, :profiling_enabled, false)
    :ok
  end

  test "data is not processed after #{end_of_data()} message" do
    dataset =
      TDG.create_dataset(
        technical: %{
          schema: [
            %{name: "name", type: "map", subSchema: [%{name: "first", type: "string"}, %{name: "last", type: "string"}]}
          ]
        }
      )
    input_topic = TopicHelper.input_topic_name(dataset.id)
    output_topic = TopicHelper.output_topic_name(dataset.id)

    data_message =
      TDG.create_data(%{
        dataset_id: dataset.id,
        payload: %{"name" => %{"first" => "Ben", "last" => "Brewer"}}
      })

    message_to_not_consume =
      TDG.create_data(%{dataset_id: dataset.id, payload: %{"name" => %{"first" => "Post", "last" => "Man"}}})

    Brook.Event.send(:valkyrie, data_ingest_start(), :author, dataset)

    Testing.Kafka.wait_for_topic(@endpoints, input_topic)

    Testing.Kafka.produce_messages([data_message, end_of_data()], input_topic, @endpoints)

    eventually(
      fn ->
        assert data_standarization_end_event_fired("event-stream", @endpoints)
        assert not is_dataset_supervisor_alive?(dataset.id)
      end,
      1000,
      30
    )

    Testing.Kafka.produce_messages([message_to_not_consume], input_topic, @endpoints)

    eventually fn ->
      messages = Testing.Kafka.fetch_messages(output_topic, @endpoints, SmartCity.Data)

      assert messages == [data_message, end_of_data()]
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

  defp is_dataset_supervisor_alive?(dataset_id) do
    case Valkyrie.Stream.Registry.whereis(dataset_id) do
      nil -> false
      :undefined -> false
      pid -> Process.alive?(pid)
    end
  end
end
