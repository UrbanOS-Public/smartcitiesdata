defmodule SmartCity.Data.Timing.Behaviour do
  @callback current_time() :: String.t()
end
