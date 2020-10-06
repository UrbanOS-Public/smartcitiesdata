defmodule Andi.Services.DatasetStore do
  @moduledoc """
  An Abstraction that handle the specifics of the Brook View state for andi dataset.
  """

  @instance_name Andi.instance_name()

  @collection :dataset
  @collection_ingested_time :ingested_time

  # Brook View State for collection dataset

  def update(%SmartCity.Dataset{} = dataset) do
    Brook.ViewState.merge(@collection, dataset.id, dataset)
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

  # Brook View State for collection ingested time

  def get_ingested_time!(id) do
    Brook.get!(@instance_name, @collection_ingested_time, id)
  end

  def get_all_ingested_time!() do
    Brook.get_all_values!(@instance_name, @collection_ingested_time)
  end

  def delete_ingested_time(id) do
    Brook.ViewState.delete(@collection_ingested_time, id)
  end
end
