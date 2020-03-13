defmodule Providers.Timestamp do
  def provide("1", _opts) do
    NaiveDateTime.utc_now() |> NaiveDateTime.to_iso8601()
  end
end
