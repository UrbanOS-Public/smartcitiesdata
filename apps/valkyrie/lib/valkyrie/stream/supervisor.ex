defmodule Valkyrie.Stream.Supervisor do
  @moduledoc """
  `DynamicSupervisor` implementation. See
  [Management.Supervisor](../../../../management/lib/management/supervisor.ex)
  for more details.
  """
  use Management.Supervisor, name: __MODULE__

  @impl true
  def say_my_name(dataset_id) do
    Valkyrie.Stream.Registry.via(dataset_id)
  end

  @impl true
  def on_start_child(dataset_id, name) do
    case Brook.get(:valkyrie, :datasets, dataset_id) do
      {:ok, dataset} when not is_nil(dataset) ->
        {Valkyrie.Stream, dataset_id: dataset_id, schema: dataset.technical.schema, profiling_enabled: Application.get_env(:valkyrie, :profiling_enabled), name: name}

      _ ->
        {:error, :dataset_not_in_view_state}
    end
  end
end
