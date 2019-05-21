defmodule Reaper.Decoder.Unknown do
  @moduledoc """
  Decoder implementation that always returns an error tuple
  """
  alias Reaper.ReaperConfig
  @behaviour Reaper.Decoder

  @impl Reaper.Decoder
  def decode({:file, _filename}, %ReaperConfig{sourceFormat: other}) do
    {:error, "", %RuntimeError{message: "#{other} is an invalid format"}}
  end

  @impl Reaper.Decoder
  def handle?(_source_format) do
    true
  end
end
