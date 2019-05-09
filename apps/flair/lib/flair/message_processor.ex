defmodule Flair.MessageProcessor do
  @moduledoc """
  Receives messages from kafka and then process them. Uses tasks to apply both flows asynchronously, but then only commits the offset once all tasks are complete.
  """

  use KafkaEx.GenConsumer

  @timeout_override Application.get_env(:flair, :task_timeout, 5 * 60 * 1_000)

  def handle_message_set(message_set, state) do
    tasks = [
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

  def handle_info({:EXIT, _pid, :normal}, state) do
    {:noreply, state}
  end
end
