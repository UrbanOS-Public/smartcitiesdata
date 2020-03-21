defmodule DiscoveryApi.Data.SystemNameCache do
  @moduledoc """
  Simple module to cache systemName to dataset_id mapping
  """
  require Logger

  def child_spec([]) do
    Cachex.child_spec(cache_name())
  end

  def cache_name() do
    :system_name_cache
  end

  def put(id, org_name, data_name) do
    Cachex.put(cache_name(), {org_name, data_name}, id)
  end

  def get(org_name, data_name) do
    Cachex.get!(cache_name(), {org_name, data_name})
  end

  def delete(org_name, data_name) do
    Cachex.del(cache_name(), {org_name, data_name})
  end
end
