defmodule Raptor.Services.DatasetStore do
  @moduledoc """
  An Abstraction that handle the specifics of the Brook View state for a raptor dataset.
  """

  @instance_name Raptor.instance_name()

  @collection :dataset

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
end
