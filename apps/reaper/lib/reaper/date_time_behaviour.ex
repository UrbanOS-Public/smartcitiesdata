defmodule Reaper.DateTimeBehaviour do
  @callback to_unix(DateTime.t()) :: integer()
  @callback to_string(DateTime.t()) :: String.t()
  @callback utc_now() :: DateTime.t()
end