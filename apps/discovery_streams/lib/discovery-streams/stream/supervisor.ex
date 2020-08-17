defmodule DiscoveryStreams.Stream.Supervisor do
  @moduledoc """
  `DynamicSupervisor` implementation. See
  [Management.Supervisor](../../../../management/lib/management/supervisor.ex)
  for more details.
  """
  use Management.Supervisor, name: __MODULE__

  @impl true
  def say_my_name(%SmartCity.Dataset{} = dataset) do
    dataset.id
    |> DiscoveryStreams.Stream.Registry.via()
  end

  @impl true
  def on_start_child(dataset, name) do
    {DiscoveryStreams.Stream, dataset: dataset, name: name}
  end
end
