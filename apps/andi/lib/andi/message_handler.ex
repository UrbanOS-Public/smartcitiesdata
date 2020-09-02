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

  def handle_message(%Elsa.Message{value: value}, state) do
    dlq_message = Jason.decode!(value)
    dataset_id = Map.get(dlq_message, "dataset_id")

    Datasets.update_latest_dlq_message(dataset_id, dlq_message)

    {:ack, state}
  end

  def handle_message(message, state) do
    Logger.warn("Could not process DLQ message #{message}")

    {:ack, state}
  end
end
