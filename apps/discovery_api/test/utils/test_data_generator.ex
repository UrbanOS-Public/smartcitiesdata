defmodule DiscoveryApi.TestDataGenerator do
  @moduledoc """
  Strategic stopgap maneuver to bridge the gap between SmartCity.Registry structs and the new SmartCity data structs.
  This conversation was marked as resolved by ManApart
  """
  def create_dataset(term) do
    term
    |> SmartCity.TestDataGenerator.create_dataset()
    |> to_registry_module()
  end

  def create_organization(term) do
    SmartCity.TestDataGenerator.create_organization(term)
    |> Map.from_struct()
    |> SmartCity.Registry.Organization.new()
    |> elem(1)
  end

  defp to_registry_module(%SmartCity.Dataset{} = dataset) do
    map = Map.from_struct(dataset)
    map = Map.put(map, :business, Map.from_struct(Map.get(map, :business)))
    map = Map.put(map, :technical, Map.from_struct(Map.get(map, :technical)))

    {:ok, data} = SmartCity.Registry.Dataset.new(map)

    data
  end
end
