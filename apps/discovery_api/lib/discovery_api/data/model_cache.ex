defmodule DiscoveryApi.Data.ModelCache do
  @moduledoc """
  Short-TTL cache in front of DiscoveryApi.Data.Model.get_all/0.

  get_all/0 is called on every authenticated `/query` request (once directly
  in QueryAccessUtils.map_affected_tables_to_models/1, plus once per table in
  a few other access-check paths) and, before this cache, re-fetched the
  entire dataset catalog from Brook's Redis-backed view state on every single
  call - no caching at all. Under Redis latency/pressure this turned every
  request into a Redix round trip that could hang or crash, and multiplied
  load on Redis exactly when it was least able to take it.

  The model catalog changes on the order of minutes (dataset create/update/
  delete), not per-request, so a short TTL safely absorbs that request
  volume into roughly one real fetch per TTL window.

  Also fails fast and never raises into the caller: if the underlying fetch
  crashes (e.g. a Redix timeout), Cachex's Courier catches it and this module
  logs it and returns an empty list rather than propagating the crash - so a
  period of backend failures degrades query/authorization results instead of
  crashing request processes and holding their memory open.
  """
  use Properties, otp_app: :discovery_api
  require Cachex.Spec
  require Logger

  getter(:ttl_ms, generic: true, default: 30_000)

  @cache_name :model_cache
  @all_key :all

  def child_spec(_) do
    Supervisor.child_spec(
      {Cachex, name: @cache_name, expiration: Cachex.Spec.expiration(default: ttl_ms())},
      id: __MODULE__
    )
  end

  @doc """
  Returns the cached result of `fetch_fun.()`, re-running it at most once per
  TTL window. Concurrent callers during a cache miss share a single
  in-flight call (Cachex's Courier dedups by key) instead of each
  independently hitting the backend - important during exactly the kind of
  backend degradation that causes a miss in the first place.
  """
  def get_all(fetch_fun) when is_function(fetch_fun, 0) do
    case Cachex.fetch(@cache_name, @all_key, fn -> {:commit, fetch_fun.()} end) do
      {:ok, models} ->
        models

      {:commit, models} ->
        models

      {:error, reason} ->
        Logger.error("ModelCache: get_all fetch failed, returning empty result: #{inspect(reason)}")
        []
    end
  end

  def invalidate do
    Cachex.clear(@cache_name)
  end
end
