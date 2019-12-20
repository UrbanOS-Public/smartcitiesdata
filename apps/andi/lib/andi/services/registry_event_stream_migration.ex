defmodule Andi.Services.RegistryEventStreamMigration do
  @moduledoc """
  Allows migration of datasets in SmartCity.Registry to the Event Stream.
  """
  import Andi
  import SmartCity.Event, only: [dataset_update: 0]

  def print_all_registry_ids do
    ids = SmartCity.Registry.Dataset.get_all!() |> Enum.map(fn ds -> ds.id end) |> Enum.intersperse("\",\"")
    IO.puts("[\"#{ids}\"]")
  end

  def migrate_registry_datasets_to_event_stream() do
    ids = SmartCity.Registry.Dataset.get_all!() |> Enum.map(fn ds -> ds.id end)
    migrate_registry_datasets_to_event_stream(ids)
  end

  def migrate_registry_datasets_to_event_stream(dataset_ids) do
    Enum.each(dataset_ids, &migrate/1)
  end

  defp migrate(dataset_id) do
    Process.sleep(1_500)
    Brook.Event.send(instance_name(), dataset_update(), :andi, lookup(dataset_id))
  end

  defp lookup(dataset_id) do
    case Brook.get(instance_name(), :dataset, dataset_id) do
      {:ok, nil} -> SmartCity.Registry.Dataset.get!(dataset_id) |> to_dataset()
      {:ok, dataset} -> dataset
    end
  end

  defp to_dataset(%SmartCity.Registry.Dataset{id: id, technical: technical, business: business}) do
    {:ok, dataset} = SmartCity.Dataset.new(%{id: id, technical: Map.from_struct(technical), business: Map.from_struct(business)})
    dataset
  end
end
