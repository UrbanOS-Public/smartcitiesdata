defmodule Flair.MessageProcessor do
  @moduledoc false

  use KafkaEx.GenConsumer

  @timeout_override Application.get_env(:flair, :timeout_override, 50)

  def handle_message_set(message_set, state) do
    tasks = [
      Task.async(fn ->
        Flair.Producer.add_messages(:quality, message_set)
      end),
      Task.async(fn ->
        Flair.Producer.add_messages(:durations, message_set)
      end)
    ]

    tasks_with_results = Task.yield_many(tasks, @timeout_override)

    for result <- tasks_with_results do
      case result do
        {_, {:ok, _value}} ->
          nil

        error ->
          raise "Couldn't complete all tasks: #{inspect(error)}"
      end
    end

    {:async_commit, state}
  end
end
