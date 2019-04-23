defmodule Flair.MessageProcessor do
  @moduledoc false

  use KafkaEx.GenConsumer

  def handle_message_set(message_set, state) do
    Flair.Producer.add_messages(message_set)
    # Flair.Producer.add_messages(:quality, message_set)

    # tasks = [
    #   Task.async(fn ->
    #     Flair.Producer.add_messages(:duration, message_set)
    #   end),
    #   Task.async(fn ->
    #     Flair.Producer.add_messages(:quality, message_set)
    #   end)
    # ]

    # tasks_with_results = Task.yield_many(tasks, 5 * 60 * 1_000)

    # for result <- tasks_with_results do
    #   case result do
    #     {:ok, value} -> nil
    #     error -> raise "Couldn't complete all tasks: #{inspect(error)}"
    #   end
    # end

    {:async_commit, state}
  end
end
