defmodule Reaper.ProcessorBehaviour do
  @callback process(any(), any()) :: any()
end