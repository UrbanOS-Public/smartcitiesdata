defmodule Reaper.Cache.AuthCache do
  @moduledoc """
  Simple module to cache auth to ingestion_id mapping
  """
  require Logger

  def child_spec([]) do
    Cachex.child_spec(cache_name())
  end

  def cache_name() do
    :auth_cache
  end

  def put(id, auth, opts \\ []) do
    Cachex.put(cache_name(), id, auth, opts)
  end

  def get(id) do
    Cachex.get!(cache_name(), id)
  end
end
