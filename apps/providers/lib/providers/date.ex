defmodule Providers.Date do
  @moduledoc """
  This provider implementation returns a formatted date with the given Timex formatting found:https://hexdocs.pm/timex/Timex.Format.DateTime.Formatters.Default.html
  """
  @behaviour Providers.Provider

  def provide("1", opts) do
    format = Map.get(opts, :format, "{ISO:Extended}")
    offset = Map.get(opts, :offset_in_days, 0) |> Timex.Duration.from_days()

    Timex.now()
    |> Timex.add(offset)
    |> Timex.format!(format)
  end
end
