defmodule Valkyrie.MessageHandler do
  def handle_messages(messages) do
    messages |> IO.inspect(label: "Received messages")

    Enum.each(messages, fn %{key: key, value: value} ->
      Kaffe.Producer.produce_sync(key, value)
    end)

    :ok
  end

end


