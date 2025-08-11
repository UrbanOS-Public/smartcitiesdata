defmodule Reaper.TransitRealtimeBehaviour do
  @callback decode(iodata()) :: term() | no_return()
end