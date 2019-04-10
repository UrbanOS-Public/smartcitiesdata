defmodule DiscoveryApi.Data.SystemNameCache do
  @moduledoc """
  Simple module to cache systemName to dataset_id mapping
  """

  def child_spec([]) do
    Cachex.child_spec(cache_name())
  end

  def cache_name() do
    :system_name_cache
  end

  def put(%SmartCity.Dataset{id: dataset_id, technical: %{dataName: data_name, orgName: org_name}}) do
    Cachex.put(cache_name(), {org_name, data_name}, dataset_id)
  end

  def get(org_name, data_name) do
    Cachex.get!(cache_name(), {org_name, data_name})
  end
end
