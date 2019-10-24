defmodule DiscoveryApi.TestDataGenerator do
  @moduledoc """
  Strategic stopgap maneuver to bridge the gap between SmartCity.Registry structs and the new SmartCity data structs.
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

  def create_schema_organization(overrides \\ %{}) do
    smart_city_organization = SmartCity.TestDataGenerator.create_organization(overrides)

    %DiscoveryApi.Schemas.Organizations.Organization{
      id: smart_city_organization.id,
      description: smart_city_organization.description,
      ldap_dn: smart_city_organization.dn,
      name: smart_city_organization.orgName,
      title: smart_city_organization.orgTitle,
      logo_url: smart_city_organization.logoUrl,
      homepage: smart_city_organization.homepage
    }
  end
end
