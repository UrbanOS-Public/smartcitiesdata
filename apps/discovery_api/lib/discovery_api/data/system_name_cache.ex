defmodule DiscoveryApi.Data.SystemNameCache do
  @moduledoc """
  Simple module to cache systemName to dataset_id mapping
  """
  require Logger

  alias SmartCity.Registry.Dataset
  alias SmartCity.Registry.Organization

  def child_spec([]) do
    Cachex.child_spec(cache_name())
  end

  def cache_name() do
    :system_name_cache
  end

  def put(%Dataset{id: dataset_id, technical: %{dataName: data_name}}, %Organization{orgName: org_name}) do
    Cachex.put(cache_name(), {org_name, data_name}, dataset_id)
  end

  def get(org_name, data_name) do
    Cachex.get!(cache_name(), {org_name, data_name})
  end
end
