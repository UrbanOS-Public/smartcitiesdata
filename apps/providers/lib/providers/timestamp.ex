defmodule Providers.Timestamp do
  @moduledoc """
  This provider implementation returns an ISO8601 compliant date string.
  """
  @behaviour Providers.Provider
  def provide("1", _opts) do
    NaiveDateTime.utc_now() |> NaiveDateTime.to_iso8601()
  end
end
