defmodule Odo do
  @moduledoc """
  Convenience functions for the Odo application.
  """

  def event_stream_instance() do
    Application.get_env(:odo, :brook)
    |> Keyword.fetch!(:instance)
  end
end
