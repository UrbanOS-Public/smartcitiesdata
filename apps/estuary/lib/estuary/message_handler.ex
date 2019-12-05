defmodule Estuary.MessageHandler do
  use Elsa.Consumer.MessageHandler
  require Logger

  def handle_messages(messages) do
    IO.inspect(messages)

    Enum.each(messages, fn message ->
      case message.value |> Jason.decode() do
        {:ok, body} ->
          with %{"author" => author, "create_ts" => create_ts, "data" => data, "type" => type} <- body do
            Estuary.EventTable.insert_event(
              author,
              create_ts,
              data,
              type
            )
          else
            err ->
              IO.inspect(err, label: "err>>>>>>>>>>>>>")
              Elsa.produce([localhost: 9092], "streaming-dead-letters", message.value)
          end
        {:error, reason} ->
          Elsa.produce(
            [localhost: 9092],
            "streaming-dead-letters",
            message.value
          )
      end
    end)

    Logger.debug("Messages #{inspect(messages)} were sent to the eventstream")
    :ack
  end
end
