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

  def put(%SmartCity.Dataset{id: dataset_id, technical: %{orgId: org_id, dataName: data_name}}) do
    case SmartCity.Organization.get(org_id) do
      {:ok, org} -> Cachex.put(cache_name(), {org.orgName, data_name}, dataset_id)
      _ -> Logger.warn("Unable to lookup organization (#{org_id}) for dataset #{dataset_id}")
    end
  end

  def get(org_name, data_name) do
    Cachex.get!(cache_name(), {org_name, data_name})
  end
end
