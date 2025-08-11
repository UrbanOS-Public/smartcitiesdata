defmodule Reaper.TimexBehaviour do
  @callback now() :: DateTime.t()
end