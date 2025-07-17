defmodule Estuary.MessageHandlerBehaviour do
  @callback handle_messages(any()) :: any()
end
