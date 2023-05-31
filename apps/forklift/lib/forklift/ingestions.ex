defmodule Forklift.Ingestions do
  @moduledoc """
  An Abstraction that handle the specifics of the Brook View state for forklift ingestions.
  """

  @instance_name Forklift.instance_name()

  @collection :ingestions

  def update(%SmartCity.Ingestion{} = ingestion) do
    Brook.ViewState.merge(@collection, ingestion.id, ingestion)
  end

  def get!(id) do
    Brook.get!(@instance_name, @collection, id)
  end

  def get_all!() do
    Brook.get_all_values!(@instance_name, @collection)
  end

  def get_events!(id) do
    Brook.get_events!(@instance_name, @collection, id)
  end

  def delete(id) do
    Brook.ViewState.delete(@collection, id)
  end
end
