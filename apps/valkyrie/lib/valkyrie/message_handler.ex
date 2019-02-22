require Logger

defmodule Valkyrie.MessageHandler do
  def handle_messages(messages) do
    Logger.info("#{__MODULE__}: Received #{length(messages)} messages.")

    Enum.each(messages, fn %{key: key, value: value} ->
      Kaffe.Producer.produce_sync(key, value)
    end)

    Logger.info("#{__MODULE__}: All messages handled without crashing.")

    :ok
  end
end
