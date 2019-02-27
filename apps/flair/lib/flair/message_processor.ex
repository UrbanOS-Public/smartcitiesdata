defmodule Flair.MessageProcessor do
  @moduledoc """
   messages
   |> GenStage.call()
   |> case do
      :uploaded -> :ok
      :buffered -> {:ok, :no_commit}

    GenStage
  """
  def handle_messages(messages) do
    Flair.Producer.add_messages(messages)

    :ok
  end
end

# {"metadata":{},"operational":{},"payload":null}
