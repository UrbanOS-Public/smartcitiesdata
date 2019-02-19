defmodule Valkyrie.MessageHandler do
  def handle_message(%{key: key, value: value}) do
    Kaffe.Producer.produce_sync(key, value)

    :ok
  end

end


