defmodule DiscoveryStreams.Init do
  @moduledoc """
  Implementation of `Initializer` behaviour to reconnect to
  pre-existing event state.
  """
  use Initializer,
    name: __MODULE__,
    supervisor: DiscoveryStreams.Stream.Supervisor
  
  defp stream_supervisor() do
    Application.get_env(:discovery_streams, :stream_supervisor, DiscoveryStreams.Stream.Supervisor)
  end
  
  defp brook() do
    Application.get_env(:discovery_streams, :brook, Brook)
  end

  def on_start(state) do
    with {:ok, view_state} <- brook().get_all(:discovery_streams, :streaming_datasets_by_system_name) do
      Enum.each(view_state, fn {_, dataset_id} -> stream_supervisor().start_child(dataset_id) end)

      Ok.ok(state)
    end
  end
end
