defmodule Providers.Timestamp do
  @moduledoc """
  This provider implementation returns the current timestamp in UTC as an ISO8601 compliant date string.

  Version 2 provides additional options:
  + format: Timex compliant format for the result
  + timezone: Timex compliant timezone. Full name is recommended for readability and DST compliance: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
  + offset_in_seconds: Time offset in seconds, positive for future times, negative for past times.
  """
  @behaviour Providers.Provider

  def provide("1", _opts) do
    NaiveDateTime.utc_now() |> NaiveDateTime.to_iso8601()
  end

  def provide("2", opts) do
    format = Map.get(opts, :format, "{ISO:Extended:Z}")
    timezone = Map.get(opts, :timezone, :utc)
    offset = Map.get(opts, :offset_in_seconds, 0)
    Timex.now(timezone) |> Timex.shift(seconds: offset) |> Timex.format!(format)
  end
end
