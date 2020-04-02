defmodule Providers.Timestamp do
  @moduledoc """
  This provider implementation returns the current timestamp in UTC as an ISO8601 compliant date string.
  """
  @behaviour Providers.Provider

  def provide("1", _opts) do
    NaiveDateTime.utc_now() |> NaiveDateTime.to_iso8601()
  end

  def provide("2", opts) do
    case Map.get(opts, :format) do
      nil -> NaiveDateTime.utc_now() |> NaiveDateTime.to_iso8601()
      format -> NaiveDateTime.utc_now() |> Timex.format!(format)
    end
  end
end
