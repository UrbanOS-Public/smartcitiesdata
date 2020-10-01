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
    case Brook.get(:valkyrie, :datasets_by_id, dataset_id) do
      {:ok, schema} when not is_nil(schema) ->
        {Valkyrie.Stream, dataset_id: dataset_id, schema: schema, name: name}

      _ ->
        {:error, :dataset_not_in_view_state}
    end
  end
end
