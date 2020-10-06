defmodule Valkyrie.Init do
  @moduledoc """
  Implementation of `Initializer` behaviour to reconnect to
  pre-existing event state.
  """
  use Initializer,
    name: __MODULE__,
    supervisor: Valkyrie.Stream.Supervisor

  def on_start(state) do
    with {:ok, view_state} <- Brook.get_all(:valkyrie, :datasets) do
      Enum.each(view_state, fn {dataset_id, _schema} -> Valkyrie.Stream.Supervisor.start_child(dataset_id) end)

      Ok.ok(state)
    end
  end
end
