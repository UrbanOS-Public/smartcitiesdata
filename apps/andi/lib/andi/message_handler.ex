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
    IO.puts("started batch on DLQ of length #{length(messages)}")
    Enum.each(messages, &handle_message(&1, state))
    IO.puts("finished batch on DLQ")

    {:ack, state}
  end

  def handle_message(%Elsa.Message{topic: @dead_letter_topic, timestamp: nil, value: value}, state) do
    value
    |> Jason.decode!()
    |> add_current_time_to_message()
    |> Datasets.update_latest_dlq_message()

    {:ack, state}
  end

  def handle_message(%Elsa.Message{topic: @dead_letter_topic, timestamp: timestamp, value: value}, state) do
    {:ok, timestamp_datetime} =
      timestamp
      |> DateTime.from_unix!(:millisecond)
      |> DateTime.shift_zone("Etc/UTC")

    iso_datetime = DateTime.to_iso8601(timestamp_datetime)

    value
    |> Jason.decode!()
    |> Map.put("timestamp", iso_datetime)
    |> Datasets.update_latest_dlq_message()

    {:ack, state}
  end

  def handle_message(%Elsa.Message{topic: @dead_letter_topic, value: value}, state) do
    value
    |> Jason.decode!()
    |> add_current_time_to_message()
    |> Datasets.update_latest_dlq_message()

    {:ack, state}
  end

  def handle_message(message, state) do
    message_as_json =
      message
      |> Map.from_struct()
      |> Jason.encode!()

    Logger.warn("Could not process message #{message_as_json}")

    {:ack, state}
  end

  defp add_current_time_to_message(dlq_message) do
    current_time = DateTime.utc_now() |> DateTime.to_iso8601()

    Map.put(dlq_message, "timestamp", current_time)
  end
end
