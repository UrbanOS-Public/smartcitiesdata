defmodule Andi.MessageHandler do
  @moduledoc false

  use Elsa.Consumer.MessageHandler
  require Logger

  alias Andi.InputSchemas.Datasets

  @dead_letter_topic Application.get_env(:andi, :dead_letter_topic)

  def init(_) do
    {:ok, %{}}
  end

  def handle_messages(messages, state) do
    dlq_messages =
      Enum.reduce(messages, %{}, fn message, acc ->
        case handle_message(message) do
          :invalid_message ->
            acc

          message ->
            Map.get(message, "dataset_ids")
            |> Enum.reduce(acc, fn dataset_id, inner_acc ->
              Map.put(inner_acc, dataset_id, message)
            end)
        end
      end)

    dlq_messages
    |> Map.values()
    |> Enum.each(&Datasets.update_latest_dlq_message/1)

    {:ack, state}
  end

  def handle_message(%Elsa.Message{topic: @dead_letter_topic, timestamp: nil, value: value}) do
    dataset_id = dataset_id_from_dlq_message(value)

    %{"dataset_id" => dataset_id} |> add_current_time_to_message()
  end

  def handle_message(%Elsa.Message{topic: @dead_letter_topic, timestamp: timestamp, value: value}) do
    {:ok, timestamp_datetime} =
      timestamp
      |> DateTime.from_unix!(:millisecond)
      |> DateTime.shift_zone("Etc/UTC")

    iso_datetime = DateTime.to_iso8601(timestamp_datetime)

    dataset_id = dataset_id_from_dlq_message(value)

    %{"dataset_id" => dataset_id, "timestamp" => iso_datetime}
  end

  def handle_message(%Elsa.Message{topic: @dead_letter_topic, value: value}) do
    dataset_id = dataset_id_from_dlq_message(value)

    %{"dataset_id" => dataset_id} |> add_current_time_to_message()
  end

  def handle_message(message) do
    message_as_json =
      message
      |> Map.from_struct()
      |> Jason.encode!()

    Logger.warn("Could not process message #{message_as_json}")
    :invalid_message
  end

  defp add_current_time_to_message(dlq_message) do
    current_time = DateTime.utc_now() |> DateTime.to_iso8601()

    Map.put(dlq_message, "timestamp", current_time)
  end

  defp dataset_id_from_dlq_message(message) do
    message
    |> Jason.decode!()
    |> Map.get("dataset_id")
  end
end
