defmodule Andi.Services.IngestionStore do
  @moduledoc """
  An Abstraction that handle the specifics of the Brook View state for andi ingestion.
  """

  @instance_name Andi.instance_name()

  @collection :ingestion

  # Brook View State for collection dataset

  def update(%SmartCity.Ingestion{} = ingestion) do
    Brook.ViewState.merge(@collection, ingestion.id, ingestion)
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
