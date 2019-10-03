defmodule Forklift.Datasets do
  @moduledoc """
  An Abstraction that handle the specifics of the Brook View state for forklift datasets.
  """

  @collection :datasets

  def update(%SmartCity.Dataset{} = dataset) do
    Brook.ViewState.merge(@collection, dataset.id, dataset)
  end

  def get!(id) do
    Brook.get!(:forklift, @collection, id)
  end

  def get_all!() do
    Brook.get_all_values!(:forklift, @collection)
  end

  def get_events!(id) do
    Brook.get_events!(:forklift, @collection, id)
  end
end
