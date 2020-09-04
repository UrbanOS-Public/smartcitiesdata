defmodule Andi.MessageHandler do
  @moduledoc false

  use Elsa.Consumer.MessageHandler
  require Logger

  alias Andi.InputSchemas.Datasets

  def init(_) do
    {:ok, %{}}
  end

  def handle_messages(messages, state) do
    Enum.each(messages, &handle_message(&1, state))

    {:ack, state}
  end

  def handle_message(%Elsa.Message{timestamp: nil, value: value}, state) do
    value
    |> Jason.decode!()
    |> add_current_time_to_message()
    |> Datasets.update_latest_dlq_message()

    {:ack, state}
  end

  def handle_message(%Elsa.Message{timestamp: timestamp, value: value}, state) do
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

  def handle_message(%Elsa.Message{value: value}, state) do
    value
    |> Jason.decode!()
    |> add_current_time_to_message()
    |> Datasets.update_latest_dlq_message()

    {:ack, state}
  end

  def handle_message(message, state) do
    Logger.warn("Could not process DLQ message #{message}")

    {:ack, state}
  end

  defp add_current_time_to_message(dlq_message) do
    current_time = DateTime.utc_now() |> DateTime.to_iso8601()

    Map.put(dlq_message, "timestamp", current_time)
  end
end
