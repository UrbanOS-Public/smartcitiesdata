# Discovery API — Trino Query Stats

Tracks the number of unique queries executed against Trino and the average
execution time per query within a rolling hourly window.

## How it works

### Collection

`DiscoveryApi.Stats.QueryStats` is an `Agent` that holds in-memory state:

| Field | Type | Description |
|---|---|---|
| `query_data` | `map` | `%{md5_hash => %{count, total_ms}}` — per-query execution count and cumulative duration |
| `total_count` | integer | Total number of query executions since last reset |
| `total_duration_ms` | integer | Cumulative execution time in milliseconds since last reset |

Three call sites feed data into the agent:

| Location | Query type | Timing method |
|---|---|---|
| `PrestoService.preview/4` | Synchronous (`Prestige.query!`) | `:timer.tc/1` wraps the call; result converted from µs to ms |
| `DataController.query/2` | Streaming (`Prestige.stream!`) | `QueryStats.wrap_stream/2` — fires after stream is fully consumed |
| `MultipleDataController.query/2` | Streaming (`Prestige.stream!`) | `QueryStats.wrap_stream/2` — fires after stream is fully consumed |

`wrap_stream/2` uses `Stream.transform/4`'s after-function, which is called
when the stream finishes or is halted by the client, so timing reflects the
full Trino round-trip including result transfer.

Recording is non-blocking — both `preview/4` and the stream wrapper dispatch
to `Task.start/1` so the hot path is never delayed.

### Flushing to Redis

The Quantum scheduler calls `MetricsService.flush_query_stats_to_redis/0`
every 5 minutes. The entire stats map is JSON-encoded with `Jason.encode!/1`
and written to a **single key** with `SET`:

```
discovery_api:query_stats  →  JSON string
```

Example value:

```json
{
  "unique_query_count": 42,
  "total_query_count": 187,
  "overall_avg_duration_ms": 340.15,
  "per_query_avg_duration_ms": {
    "A3F1B2...": 250.0,
    "9C4E77...": 430.5
  }
}
```

Each flush overwrites the previous value. Values always reflect the current
hourly window (see Reset below).

A log line is emitted at `info` level on every flush:

```
Query stats flushed to Redis — unique=42 total=187 overall_avg_ms=340.15
```

To inspect the current stats from the Redis CLI:

```
GET discovery_api:query_stats
```

### Reset

The Quantum scheduler calls `QueryStats.reset/0` at the top of every hour
(`0 * * * *`), clearing `query_data` and zeroing the counters. The next Redis
flush after the reset will write zeroed values until new queries arrive.

## Scheduler jobs

Defined in `config/config.exs`:

```elixir
{"*/5 * * * *", {DiscoveryApi.Services.MetricsService, :flush_query_stats_to_redis, []}},
{"0 * * * *",   {DiscoveryApi.Stats.QueryStats, :reset, []}}
```

## Uniqueness semantics

Two queries are considered the same if their SQL strings are byte-for-byte
identical after MD5 hashing. This means queries that differ only in
whitespace, parameter values, or column ordering are counted as distinct.
Normalization (trimming, lowercasing, parameter extraction) was intentionally
omitted to keep the implementation simple; add it in `QueryStats.record/2` if
semantic deduplication becomes necessary.

## Modified files

| File | Change |
|---|---|
| `apps/discovery_api/lib/discovery_api/stats/query_stats.ex` | New — `Agent` that tracks per-query and overall stats; exposes `record/2`, `stats/0`, `reset/0`, `wrap_stream/2` |
| `apps/discovery_api/lib/discovery_api/services/metrics_service.ex` | Added `flush_query_stats_to_redis/0` — JSON-encodes stats and writes to Redis |
| `apps/discovery_api/lib/discovery_api/application.ex` | Added `QueryStats` to the supervision tree |
| `apps/discovery_api/config/config.exs` | Added two Quantum jobs: flush every 5 minutes, reset every hour |
| `apps/discovery_api/lib/discovery_api/services/presto_service.ex` | `preview/4` wrapped with `:timer.tc/1` to record synchronous query timing |
| `apps/discovery_api/lib/discovery_api_web/controllers/data_controller.ex` | Stream pipeline extended with `QueryStats.wrap_stream/2` |
| `apps/discovery_api/lib/discovery_api_web/controllers/multiple_data_controller.ex` | Stream pipeline extended with `QueryStats.wrap_stream/2` |

## Apply to hot services

When applying these changes to a running instance without a full restart, order
matters because every modified caller depends on `QueryStats` being available
as a live process before it is reloaded.

**1. Start the `QueryStats` process**

The module is not yet in the supervision tree, so start it manually:

```elixir
Supervisor.start_child(DiscoveryApi.Supervisor, DiscoveryApi.Stats.QueryStats)
```

**2. Reload `query_stats.ex`**

The module definition must exist before any caller is reloaded:

```elixir
r DiscoveryApi.Stats.QueryStats
```

**3. Reload the four caller modules (order among these does not matter)**

```elixir
r DiscoveryApi.Services.PrestoService
r DiscoveryApi.Services.MetricsService
r DiscoveryApiWeb.DataController
r DiscoveryApiWeb.MultipleDataController
```

**4. Reload `application.ex`**

Safe at any point. The supervisor is already running so this only updates the
module definition for future restarts — it will not start a second `QueryStats`
process:

```elixir
r DiscoveryApi.Application
```

**5. Add the Quantum jobs manually**

`config.exs` is read only at boot and cannot be hot-reloaded. Add the two jobs
directly to the running scheduler:

```elixir
DiscoveryApi.Quantum.Scheduler.new_job()
|> Quantum.Job.set_schedule(Crontab.CronExpression.Parser.parse!("*/5 * * * *"))
|> Quantum.Job.set_task({DiscoveryApi.Services.MetricsService, :flush_query_stats_to_redis, []})
|> DiscoveryApi.Quantum.Scheduler.add_job()

DiscoveryApi.Quantum.Scheduler.new_job()
|> Quantum.Job.set_schedule(Crontab.CronExpression.Parser.parse!("0 * * * *"))
|> Quantum.Job.set_task({DiscoveryApi.Stats.QueryStats, :reset, []})
|> DiscoveryApi.Quantum.Scheduler.add_job()
```

> **Warning:** Loading any caller module before step 1 is complete will cause
> the first query to crash with `{:noproc, ...}` because the Agent process is
> not yet registered.

## Troubleshooting

### Redis key is missing after hot-reload

If `GET discovery_api:query_stats` returns nil, `flush_query_stats_to_redis/0`
has never successfully run. Work through the checks below in order from an IEx
console on the running node.

**1. Confirm the QueryStats process is alive**

```elixir
Process.whereis(DiscoveryApi.Stats.QueryStats)
```

Returns a PID if healthy. `nil` means the agent is not running — go back to
step 1 of the hot-reload procedure and start the process before reloading any
caller.

**2. Inspect in-memory stats**

```elixir
DiscoveryApi.Stats.QueryStats.stats()
```

If `total_query_count` is 0, either no queries have arrived since the agent
started or the caller modules were not reloaded after the agent (steps 3–4).

**3. Check the Quantum scheduler has the flush job registered**

```elixir
DiscoveryApi.Quantum.Scheduler.jobs()
```

Look for the `*/5 * * * *` entry. If it is absent, re-run step 5 of the
hot-reload procedure.

**4. Manually trigger the flush**

```elixir
DiscoveryApi.Services.MetricsService.flush_query_stats_to_redis()
```

Then query Redis immediately. If the key now exists, the flush path is healthy
but the Quantum job was never registered — re-run step 5. If the call raises,
the error will identify whether the problem is in the QueryStats agent or the
Redix connection.

### Stats are always 0 in production (multi-pod deployments)

`r Module` only reloads code on the pod whose IEx console you are connected to.
If prod runs multiple replicas, queries routed to other pods run the old code
and never call `QueryStats.record/2`. Repeat all five hot-reload steps on every
pod's IEx console.

Before doing that, confirm the agent and the full flush path work correctly on
the pod you already reloaded.

**Inject a fake query to verify end-to-end recording**

```elixir
DiscoveryApi.Stats.QueryStats.record("SELECT 1", 100)
DiscoveryApi.Stats.QueryStats.stats()
```

`total_query_count` should be 1 and `overall_avg_duration_ms` should be 100.0.
If it is, the agent is healthy and real queries are simply not reaching this pod
yet, or the controllers were not reloaded.

**Verify the controllers are running the new code**

Send a real HTTP query through the API, then check the stats again:

```elixir
DiscoveryApi.Stats.QueryStats.stats()
```

If `total_query_count` stays at 1 (only the injected fake query), the
controllers in the running image are from a pre-change build. In a compiled
release, `r Module` recompiles from the source files baked into the image at
build time. If the image was built before these changes were added, `r` silently
recompiles the old code and the wrap_stream calls are never applied. The only
fix in that case is a redeploy with an updated image.

## Caveats

- **In-memory only between flushes.** If the application restarts between
  flush intervals, up to 5 minutes of data is lost. The Redis values from the
  last successful flush remain in place.
- **Hourly window, not rolling.** Reset fires on the clock hour, so the window
  is not a true 60-minute sliding window.
- **Streaming timing includes response serialization.** The timer for streaming
  queries starts when `Prestige.stream!` is called and stops when the last
  chunk is consumed by the client, so it includes network transfer time, not
  just Trino execution time.
