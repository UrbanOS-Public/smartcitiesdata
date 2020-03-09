defmodule Andi.Services.DatasetRetrieval do
  @moduledoc """
  Interface for retrieving datasets.
  """
  import Andi

  @collection :dataset

  def get_all(instance \\ instance_name()) do
    Brook.get_all_values(instance, @collection)
  end

  def get_all!(instance \\ instance_name()) do
    case get_all(instance) do
      {:ok, datasets} -> datasets
      {:error, reason} -> raise reason
    end
  end

  def update(%SmartCity.Dataset{} = dataset) do
    Brook.ViewState.merge(@collection, dataset.id, dataset)
  end

  def get!(id, collection \\ @collection) do
    Brook.get!(instance_name(), collection, id)
  end

  def get_all_dataset!(instance \\ instance_name()) do
    Brook.get_all_values!(instance_name(), @collection)
  end

  def get_all_ingested_time!() do
    Brook.get_all_values!(instance_name(), :ingested_time)
  end

  def delete(id) do
    Brook.ViewState.delete(@collection, id)
  end
end
