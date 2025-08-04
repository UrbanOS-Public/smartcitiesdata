defmodule DiscoveryStreams.Stream.Supervisor do
  @moduledoc """
  `DynamicSupervisor` implementation. See
  [Management.Supervisor](../../../../management/lib/management/supervisor.ex)
  for more details.
  """
  use Management.Supervisor, name: __MODULE__

  @instance_name DiscoveryStreams.instance_name()

  @impl true
  def say_my_name(dataset_id) do
    DiscoveryStreams.Stream.Registry.via(dataset_id)
  end

  @impl true
  def on_start_child(dataset_id, name) do
    case Brook.get(@instance_name, :streaming_datasets_by_id, dataset_id) do
      {:ok, system_name} when not is_nil(system_name) ->
        {DiscoveryStreams.Stream, system_name: system_name, dataset_id: dataset_id, name: name}

      _ ->
        {:error, :dataset_not_in_view_state}
    end
  end
end