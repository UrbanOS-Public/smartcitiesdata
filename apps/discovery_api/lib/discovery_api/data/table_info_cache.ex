defmodule DiscoveryApi.Data.TableInfoCache do
  @moduledoc """
  Simple module to cache systemName to dataset_id mapping
  """
  require Logger

  def child_spec([]) do
    Supervisor.child_spec({Cachex, cache_name()}, id: __MODULE__)

  end

  def put(data) do
    Cachex.put(cache_name(), "table_info", data)
    data
  end

  def get() do
    Cachex.get!(cache_name(), "table_info")
  end

  def invalidate() do
    Cachex.clear(cache_name())
  end

  defp cache_name() do
    :table_info
  end
end
