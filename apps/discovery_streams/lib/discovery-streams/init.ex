defmodule DiscoveryStreams.Init do
  @moduledoc """
  Implementation of `Initializer` behaviour to reconnect to
  pre-existing event state.
  """
  use Initializer,
    name: __MODULE__,
    supervisor: DiscoveryStreams.Stream.Supervisor
  use Properties, otp_app: :discovery_streams

  getter(:brook_view_state, default: Brook)
  getter(:stream_supervisor, default: DiscoveryStreams.Stream.Supervisor)

  def on_start(state, brook_impl \\ nil, supervisor_impl \\ nil) do
    brook = brook_impl || brook_view_state()
    supervisor = supervisor_impl || stream_supervisor()
    
    with {:ok, view_state} <- brook.get_all(:discovery_streams, :streaming_datasets_by_system_name) do
      Enum.each(view_state, fn {_, dataset_id} -> supervisor.start_child(dataset_id) end)

      Ok.ok(state)
    end
  end
end