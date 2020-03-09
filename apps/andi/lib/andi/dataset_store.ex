defmodule Andi.DatasetStore do
  @moduledoc """
  An Abstraction that handle the specifics of the Brook View state for andi datasets.
  """

  import Andi

  @collection_dataset :dataset
  @collection_ingested_time :ingested_time
  @collection_org :org

  def update(%SmartCity.Dataset{} = dataset) do
    Brook.ViewState.merge(@collection_dataset, dataset.id, dataset)
  end

  def get(id) do
    Brook.get(instance_name(), @collection_dataset, id)
  end

  def get_org(id) do
    Brook.get(instance_name(), @collection_org, id)
  end

  def get_ingested_time!(id) do
    Brook.get!(instance_name(), @collection_ingested_time, id)
  end

  def get_all() do
    Brook.get_all_values(instance_name(), @collection_dataset)
  end

  def get_all_org() do
    Brook.get_all_values(instance_name(), @collection_org)
  end

  def get_all!() do
    case get_all() do
      {:ok, datasets} -> datasets
      {:error, reason} -> raise reason
    end
  end

  def get_all_dataset!() do
    Brook.get_all_values!(instance_name(), @collection_dataset)
  end

  def get_all_ingested_time!() do
    Brook.get_all_values!(instance_name(), @collection_ingested_time)
  end

  def delete(id) do
    Brook.ViewState.delete(@collection_dataset, id)
  end
end
