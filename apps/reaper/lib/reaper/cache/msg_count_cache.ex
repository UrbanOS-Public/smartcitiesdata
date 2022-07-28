defmodule Reaper.Cache.MsgCountCache do
  @moduledoc """
  Simple module to cache messages sent to ingestion_id mapping
  """
  require Logger

  def child_spec([]) do
    %{
      id: cache_name(),
      start: {Cachex, :start_link, [cache_name()]}
    }
  end

  def cache_name() do
    :msg_count_cache
  end

  def increment(ingestion_id, amount) do
    Cachex.incr(cache_name(), ingestion_id, amount)
  end

  def get(ingestion_id) do
    Cachex.get(cache_name(), ingestion_id)
  end

  def reset(ingestion_id) do
    Cachex.put(cache_name(), ingestion_id, 0)
  end
end
