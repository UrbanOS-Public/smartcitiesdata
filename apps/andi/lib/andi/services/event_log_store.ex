defmodule Andi.Services.EventLogStore do
  @moduledoc """
  An Abstraction that handle the specifics of the Brook View state for andi events.
  """

  @instance_name Andi.instance_name()

  @collection :event_log

  # Brook View State for event logs

  def update(%SmartCity.EventLog{} = event) do
    Brook.ViewState.merge(@collection, event.dataset_id, event)
  end

  def get(id) do
    Brook.get(@instance_name, @collection, id)
  end

  def get_all() do
    Brook.get_all_values(@instance_name, @collection)
  end

  def get_all!() do
    Brook.get_all_values!(@instance_name, @collection)
  end

  def delete(id) do
    Brook.ViewState.delete(@collection, id)
  end
end
