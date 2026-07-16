# Discovery API — Trino Query Cache

Caches the row results of successful Trino queries in Redis so that identical
subsequent queries are served without a Trino round-trip. Cache entries expire
after 6 minutes.

## How it works

### Cache key

The key is derived by MD5-hashing the raw SQL string and encoding it as
uppercase hex — the same computation used by `QueryStats.record/2`:

```
discovery_api:trino_cache:<MD5_HEX_OF_SQL>
```

Example:

```
discovery_api:trino_cache:B1698E52A0F16203489454196A0C6307
```

Two queries are considered identical only if their SQL strings are
byte-for-byte the same. Whitespace differences, column ordering, or parameter
value changes produce different keys and are cached independently.

### Request flow

```
Request arrives
      │
      ▼
Authorization checks (unchanged)
      │
      ▼
Redis GET discovery_api:trino_cache:<hash>
      │
   ┌──┴──────────────────────┐
   │ Hit                     │ Miss
   ▼                         ▼
Return cached rows        Execute Prestige.stream!
to view pipeline          Materialize via Enum.to_list()
                               │
                               ▼
                          Store rows in Redis
                          SETEX key 360 <json>
                               │
                               ▼
                          Return rows to view pipeline
```

On both paths the row list is passed to `map_schema?/3` and then to
`QueryStats.wrap_stream/2` before the view renders the response. The view
pipeline (CSV encoding, JSON encoding, geojson wrapping) always runs —
only the Trino round-trip is avoided on a cache hit.

### Materialization

`Prestige.stream!` is a lazy stream. On a cache miss the stream is fully
consumed into memory with `Enum.to_list/1` before serialization. This means:

- The full result set is held in the BEAM process heap during serialization.
- Queries with a `LIMIT` clause (the typical case for user-facing requests)
  are safe. Unbounded analytical queries through `MultipleDataController`
  carry a higher memory cost.

A configurable row limit guards against caching very large results:

```elixir
# config/config.exs
config :discovery_api, :query_cache,
  max_rows: 50_000
```

If the materialized list exceeds `max_rows`, the result is returned to the
client normally but is not written to Redis.

### TTL and invalidation

Cache entries are written with `SETEX` (atomic set + TTL). Every entry expires
after **360 seconds (6 minutes)**. There is no active invalidation — callers
may receive data up to 6 minutes stale. This is acceptable for read-heavy
analytical queries where datasets are updated by a separate ingestion pipeline.

Authorization checks run before the cache is consulted, so a cache hit never
bypasses access control.

### Resilience

All Redis operations use `Redix.command/2` (non-raising). Any Redis failure
— connection refused, timeout, malformed cached JSON — is treated as a cache
miss and execution falls through to Trino. A Redis outage never prevents query
serving.

### QueryStats interaction

`QueryStats.wrap_stream/2` wraps the row list on every request regardless of
cache status. On a **cache hit**, it records a near-zero duration (response
transmission time only). On a **cache miss**, it records the full Trino
round-trip including result transfer. Both are correct measurements for their
respective paths.

### Cache hit ratio tracking

Every `fetch_or_execute/2` call that resolves increments one of two permanent
Redis counters:

| Counter key | Incremented when |
|---|---|
| `discovery_api:trino_cache:hits` | `get_cached/1` returns `{:ok, rows}` |
| `discovery_api:trino_cache:misses` | `execute_fn.()` returns `{:ok, rows}` |

Execute-fn errors (Trino down, etc.) do not increment either counter — they are
neither hits nor misses. INCR failures are silently ignored (non-raising).

The counters are **cumulative** — they accumulate across pod restarts and do not
reset with the hourly `QueryStats` flush. They can be manually reset:

```
DEL discovery_api:trino_cache:hits
DEL discovery_api:trino_cache:misses
```

`MetricsService.flush_query_stats_to_redis/0` reads both counters each cycle and
merges them into the `discovery_api:query_stats` JSON entry alongside the
per-query execution stats:

```json
{
  "unique_query_count": 42,
  "total_query_count": 187,
  "overall_avg_duration_ms": 340.15,
  "per_query_avg_duration_ms": { "...": "..." },
  "cache_hits": 1523,
  "cache_misses": 321,
  "cache_hit_ratio": 0.8258
}
```

The ratio is computed as `hits / (hits + misses)`, rounded to 4 decimal places.
When both counters are zero (no queries yet), the ratio is `0.0`.

## Inspecting the cache from Redis CLI

```
# Check if a specific query is cached (compute the hash first)
GET discovery_api:trino_cache:<MD5_HEX>

# List all cache entries (including hit/miss counters)
KEYS discovery_api:trino_cache:*

# Check TTL remaining on an entry
TTL discovery_api:trino_cache:<MD5_HEX>

# Read hit/miss counters directly
GET discovery_api:trino_cache:hits
GET discovery_api:trino_cache:misses

# Manually evict an entry
DEL discovery_api:trino_cache:<MD5_HEX>
```

## Modified files

| File | Change |
|---|---|
| `apps/discovery_api/lib/discovery_api/services/query_cache.ex` | New — cache key derivation, Redis GET + SETEX, row limit guard, hit/miss INCR counters |
| `apps/discovery_api/lib/discovery_api/services/metrics_service.ex` | `flush_query_stats_to_redis/0` reads cache counters and merges `cache_hits`, `cache_misses`, `cache_hit_ratio` into query stats JSON |
| `apps/discovery_api/lib/discovery_api_web/controllers/data_controller.ex` | `query/2` — stream replaced with `QueryCache.fetch_or_execute/2` thunk; `conn.assigns.query_start_ms` added for failure timing |
| `apps/discovery_api/lib/discovery_api_web/controllers/multiple_data_controller.ex` | `query/2` — same pattern as `DataController` |
| `apps/discovery_api/config/config.exs` | Added `config :discovery_api, :query_cache, max_rows: 50_000` |

## Apply to hot services

The cache module must be compiled before either controller, since both alias
`DiscoveryApi.Services.QueryCache`.

**1. Copy source files into the pod and compile**

Run the patch script from the repo root to copy files and generate
`/tmp/task1.txt`:

```bash
./patch_discovery_api_pod.sh <pod-name> <namespace>
```

**2. Compile in the IEx console in order**

`query_cache.ex` must come first:

```elixir
c "/tmp/patch/apps/discovery_api/lib/discovery_api/services/query_cache.ex"
c "/tmp/patch/apps/discovery_api/lib/discovery_api/services/metrics_service.ex"
c "/tmp/patch/apps/discovery_api/lib/discovery_api/services/presto_service.ex"
c "/tmp/patch/apps/discovery_api/lib/discovery_api_web/controllers/data_controller.ex"
c "/tmp/patch/apps/discovery_api/lib/discovery_api_web/controllers/multiple_data_controller.ex"
```

**3. Apply the `max_rows` config**

`config.exs` cannot be hot-reloaded. The default of 50,000 is hardcoded as a
fallback in `QueryCache.store/2` and takes effect automatically without this
step. To override it at runtime:

```elixir
Application.put_env(:discovery_api, :query_cache, max_rows: 50_000)
```

**4. Verify the cache is active**

Send a query through the API twice. On the second request, confirm a cache
entry exists:

```
KEYS discovery_api:trino_cache:*
```

Or from IEx, inject a known query and inspect Redis directly:

```elixir
key = DiscoveryApi.Services.QueryCache.cache_key("SELECT id FROM some_table")
Redix.command(:redix, ["EXISTS", key])
# {:ok, 1} means the entry is present
```

## Troubleshooting

### Cache entries never appear in Redis

Check that `query_cache.ex` compiled correctly and is the version with the
`@prefix "discovery_api:trino_cache:"` attribute. If the module compiled from
an older source, `QueryCache` may not be defined or may have a different prefix.

```elixir
DiscoveryApi.Services.QueryCache.cache_key("test")
# Should return "discovery_api:trino_cache:<hash>"
```

If the function is undefined, `query_cache.ex` was not compiled. Re-run the
patch script and compile steps.

### Queries are never served from cache

Identical queries produce the same cache key only when the SQL strings are
byte-for-byte identical. Query parameters that change per request (e.g., a
`LIMIT` value embedded in the SQL, or a `WHERE` clause with a user-supplied
value) produce different keys on every request.

### Cache is populated but results look stale

This is expected behavior. Entries live for 6 minutes. To force immediate
eviction:

```
DEL discovery_api:trino_cache:<MD5_HEX>
```

## Caveats

- **Memory pressure on cache miss.** The entire result set is held in memory
  during `Enum.to_list/1` and again during `Jason.encode/1`. Large unbounded
  queries through `MultipleDataController` should use the `max_rows` guard.
- **No cross-pod cache sharing concern.** All pods connect to the same Redis
  instance, so a cache entry written by one pod is readable by all others.
- **Stats timing on cache hits.** `QueryStats` records near-zero duration on
  cache hits. The stats reflect response transmission time, not Trino execution
  time, for those requests.
- **Stale data window.** Clients may receive data up to 6 minutes old. This is
  a known trade-off, not a bug.
