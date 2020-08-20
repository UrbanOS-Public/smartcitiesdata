defmodule DiscoveryStreams.Stream.Supervisor do
  @moduledoc """
  `DynamicSupervisor` implementation. See
  [Management.Supervisor](../../../../management/lib/management/supervisor.ex)
  for more details.
  """
  use Management.Supervisor, name: __MODULE__

  @impl true
  def say_my_name(dataset_id) do
    DiscoveryStreams.Stream.Registry.via(dataset_id)
  end

  @impl true
  def on_start_child(dataset_id, name) do
    {DiscoveryStreams.Stream, dataset_id: dataset_id, name: name}
  end
end
