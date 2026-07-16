# Discovery API — Trino Query Stats (OTP25)

This document covers the OTP25/Elixir 1.14.4 implementation. The conceptual
background (how the Agent works, Redis key format, Quantum schedule, etc.) is
the same as described in `discovery_query_stats.md`. Read that document first.
This document focuses on what is **different** in the OTP25 codebase.

## OTP25 environment

| Attribute | Value |
|---|---|
| Elixir | 1.14.4-otp-25 |
| Erlang/OTP | 25.3.2 |
| Alpine | 3.18.0 |
| Docker base | `hexpm/elixir:1.14.4-erlang-25.3.2-alpine-3.18.0` |
| Repo path | `/home/rseward/src/github/urbanos/smartcitiesdata` |
| Prestige | `~> 3.0.0` |
| Redix | `~> 1.2` |

## Key differences from OTP23

### 1. Redix is injected via module attribute

OTP25 uses `Application.compile_env` module attributes for dependency
injection (matching `persistence.ex`). This is what wires `RedixMock` in tests
automatically — `config/test.exs` already includes `redix_module: RedixMock`.

In every module that calls Redis, use:

```elixir
@redix_module Application.compile_env(:discovery_api, :redix_module, Redix)
```

Then call `@redix_module.command/2` and `@redix_module.command!/2` instead of
`Redix.command/2` / `Redix.command!/2`.

### 2. No Elixir 1.10 scoping bug

The OTP23 workaround that replaced `dataset_name` with
`conn.assigns.model.systemName` inside `rescue` clauses is **not needed** in
Elixir 1.14. Local variables bound before a `with` block are visible in
`rescue` normally.

### 3. Prestige 3.x error types

The rescue clause must list `Prestige.BadRequestError` which does not exist in
older Prestige versions:

```elixir
rescue
  error in [Prestige.BadRequestError, Prestige.ConnectionError, Prestige.Error] ->
```

### 4. Controller dependency injection

OTP25 controllers call Prestige and PrestoService through compile-time module
attributes:

```elixir
@presto_service_impl Application.compile_env(:discovery_api, :presto_service, PrestoService)
@prestige_impl       Application.compile_env(:discovery_api, :prestige, Prestige)
@prestige_result_impl Application.compile_env(:discovery_api, :prestige_result, Prestige.Result)
```

All Prestige and PrestoService calls inside the controller must go through
these attributes. The session is passed as the **first** argument:

```elixir
@prestige_impl.stream!(session, query)           # not: session |> Prestige.stream!(query)
@prestige_result_impl.as_maps(result)
@presto_service_impl.get_column_names(session, dataset_name, columns_param)
```

`get_column_names_from_schema/3` does **not exist** in the OTP25 PrestoService.
Use `get_column_names/3` instead.

### 5. Tests use Mox, not Placebo

All test mocks use `Mox.stub/3` and `Mox.expect/4`. The `RedixMock` behaviour
and mock are already defined in `test/unit/support/`:
- `redix_behaviour.ex` — `@callback command/2` and `@callback command!/2`
- `mox_setup.ex` — `Mox.defmock(RedixMock, for: [RedixBehaviour])`

Replace any `allow(Redix.command(...), return: ...)` with:

```elixir
stub(RedixMock, :command, fn :redix, _ -> {:ok, nil} end)
```

## Modified files

| File | Change |
|---|---|
| `apps/discovery_api/lib/discovery_api/stats/query_stats.ex` | New — `Agent` tracking per-query and overall stats; `@redix_module` for Redis cache-ratio reads |
| `apps/discovery_api/lib/discovery_api/services/metrics_service.ex` | Added `flush_query_stats_to_redis/0`; `@redix_module` for Redis writes |
| `apps/discovery_api/lib/discovery_api/application.ex` | Add `DiscoveryApi.Stats.QueryStats` to children |
| `apps/discovery_api/config/config.exs` | Add two Quantum jobs and `query_cache` config |
| `apps/discovery_api/lib/discovery_api/services/presto_service.ex` | `preview/4` wrapped with `:timer.tc/1` |
| `apps/discovery_api/lib/discovery_api_web/controllers/data_controller.ex` | `query/2` — `wrap_stream/2`, failure timing, `conn.assigns.query_start_ms` |
| `apps/discovery_api/lib/discovery_api_web/controllers/multiple_data_controller.ex` | `query/2` — `wrap_stream/2`, failure timing |

## Code changes

### `query_stats.ex` (new file)

```elixir
defmodule DiscoveryApi.Stats.QueryStats do
  @moduledoc false
  use Agent

  @redix_module Application.compile_env(:discovery_api, :redix_module, Redix)

  def start_link(_opts) do
    Agent.start_link(fn -> initial_state() end, name: __MODULE__)
  end

  def record(sql, duration_ms) do
    hash = :crypto.hash(:md5, sql) |> Base.encode16()

    Agent.update(__MODULE__, fn state ->
      entry = Map.get(state.query_data, hash, %{count: 0, total_ms: 0})

      %{
        state
        | query_data: Map.put(state.query_data, hash, %{count: entry.count + 1, total_ms: entry.total_ms + duration_ms}),
          total_count: state.total_count + 1,
          total_duration_ms: state.total_duration_ms + duration_ms
      }
    end)
  end

  def stats do
    query_stats =
      Agent.get(__MODULE__, fn state ->
        overall_avg =
          if state.total_count > 0,
            do: state.total_duration_ms / state.total_count,
            else: 0.0

        per_query_avgs =
          Map.new(state.query_data, fn {hash, %{count: count, total_ms: total_ms}} ->
            {hash, total_ms / count}
          end)

        %{
          unique_query_count: map_size(state.query_data),
          total_query_count: state.total_count,
          overall_avg_duration_ms: overall_avg,
          per_query_avg_duration_ms: per_query_avgs
        }
      end)

    hits = read_counter("discovery_api:trino_cache:hits")
    misses = read_counter("discovery_api:trino_cache:misses")
    total = hits + misses
    hit_ratio = if total > 0, do: Float.round(hits / total, 4), else: 0.0

    Map.merge(query_stats, %{
      cache_hits: hits,
      cache_misses: misses,
      cache_hit_ratio: hit_ratio
    })
  end

  def reset do
    Agent.update(__MODULE__, fn _ -> initial_state() end)
  end

  def wrap_stream(stream, sql) do
    Stream.transform(
      stream,
      fn -> System.monotonic_time(:millisecond) end,
      fn item, start_ms -> {[item], start_ms} end,
      fn start_ms ->
        duration_ms = System.monotonic_time(:millisecond) - start_ms
        Task.start(fn -> record(sql, duration_ms) end)
      end
    )
  end

  defp read_counter(key) do
    case @redix_module.command(:redix, ["GET", key]) do
      {:ok, nil} -> 0
      {:ok, val} -> String.to_integer(val)
      _ -> 0
    end
  end

  defp initial_state do
    %{query_data: %{}, total_count: 0, total_duration_ms: 0}
  end
end
```

### `metrics_service.ex` — add `flush_query_stats_to_redis/0`

Add `@redix_module` and the new function. The existing functions are unchanged:

```elixir
defmodule DiscoveryApi.Services.MetricsService do
  @moduledoc """
  Service that collects metrics and records them to the application's metric through telemetry (which by default is prometheus)
  """

  require Logger

  @redix_module Application.compile_env(:discovery_api, :redix_module, Redix)

  # ... existing functions unchanged ...

  def record_api_hit(request_type, dataset_id) do
    @redix_module.command!(:redix, ["INCR", "smart_registry:#{request_type}:count:#{dataset_id}"])
  end

  def flush_query_stats_to_redis do
    stats = DiscoveryApi.Stats.QueryStats.stats()
    json = Jason.encode!(stats)

    @redix_module.command!(:redix, ["SET", "discovery_api:query_stats", json])

    Logger.info(
      "Query stats flushed to Redis — unique=#{stats.unique_query_count} total=#{stats.total_query_count}" <>
        " overall_avg_ms=#{Float.round(stats.overall_avg_duration_ms, 2)}" <>
        " cache_hits=#{stats.cache_hits} cache_misses=#{stats.cache_misses} hit_ratio=#{stats.cache_hit_ratio}"
    )
  end
end
```

> **Note:** `record_api_hit/2` currently calls `Redix.command!` directly in the
> OTP25 codebase. Update it to `@redix_module.command!` as shown above so the
> module attribute is consistent and tests can stub it via `RedixMock`.

### `application.ex` — add QueryStats to children

Add `DiscoveryApi.Stats.QueryStats` to the children list **before** the
Quantum scheduler so the process is alive when the first flush job fires:

```elixir
children =
  [
    {Phoenix.PubSub, [name: DiscoveryApi.PubSub, adapter: Phoenix.PubSub.PG2]},
    DiscoveryApi.Data.SystemNameCache,
    DiscoveryApiWeb.Plugs.ResponseCache,
    redis(),
    ecto_repo(),
    guardian_db_sweeper(),
    {Brook, brook()},
    cache_populator(),
    supervisor(DiscoveryApiWeb.Endpoint, []),
    DiscoveryApi.Stats.QueryStats,          # <-- add this line
    DiscoveryApi.Quantum.Scheduler,
    DiscoveryApi.Data.TableInfoCache,
    dead_letter_children()
  ]
  |> TelemetryEvent.config_init_server(@instance_name)
  |> List.flatten()
```

### `config/config.exs` — add Quantum jobs and cache config

Append to the existing `DiscoveryApi.Quantum.Scheduler` jobs block:

```elixir
config :discovery_api, DiscoveryApi.Quantum.Scheduler,
  jobs: [
    # existing job
    {"0 6 * * 1", {DiscoveryApi.Stats.StatsCalculator, :produce_completeness_stats, []}},
    # new jobs
    {"*/5 * * * *", {DiscoveryApi.Services.MetricsService, :flush_query_stats_to_redis, []}},
    {"0 * * * *",   {DiscoveryApi.Stats.QueryStats, :reset, []}}
  ]

config :discovery_api, :query_cache,
  max_rows: 50_000
```

### `presto_service.ex` — time `preview/4`

Wrap the body of `preview/4` with `:timer.tc/1`:

```elixir
def preview(session, dataset_system_name, row_limit \\ 50, schema) do
  sql_statement = "select #{format_select_statement_from_schema(schema)} from #{dataset_system_name} limit #{row_limit}"

  {duration_us, result} =
    :timer.tc(fn ->
      session
      |> Prestige.query!(sql_statement)
      |> Prestige.Result.as_maps()
      |> map_prestige_results_to_schema(schema)
    end)

  duration_ms = div(duration_us, 1000)
  Task.start(fn -> DiscoveryApi.Stats.QueryStats.record(sql_statement, duration_ms) end)
  result
end
```

### `data_controller.ex` — add wrap_stream and failure timing

**Diff from current OTP25 `query/2`:**

```elixir
def query(conn, params) do
  conn = assign(conn, :query_start_ms, System.monotonic_time(:millisecond))   # ADD
  format = get_format(conn)
  dataset_name = conn.assigns.model.systemName
  dataset_id = conn.assigns.model.id
  current_user = conn.assigns.current_user
  schema = conn.assigns.model.schema
  session = DiscoveryApi.prestige_opts() |> @prestige_impl.new_session()
  api_key = Plug.Conn.get_req_header(conn, "api_key")

  with {:ok, columns} <- @presto_service_impl.get_column_names(session, dataset_name, Map.get(params, "columns")),
       {:ok, query} <- @presto_service_impl.build_query(params, dataset_name, columns, schema),
       {:ok, affected_models} <- QueryAccessUtils.get_affected_models(query),
       true <- QueryAccessUtils.user_is_authorized?(affected_models, current_user, api_key) do
    data_stream =
      session
      |> @prestige_impl.stream!(query)
      |> Stream.flat_map(&@prestige_result_impl.as_maps/1)
      |> map_schema?(schema, format)
      |> DiscoveryApi.Stats.QueryStats.wrap_stream(query)                      # ADD

    rendered_data_stream =
      DataView.render_as_stream(:data, format, %{stream: data_stream, columns: columns, dataset_name: dataset_name, schema: schema})

    resp_as_stream(conn, rendered_data_stream, format, dataset_id)
  else
    {:error, error} ->
      duration_ms = System.monotonic_time(:millisecond) - conn.assigns.query_start_ms  # ADD
      Task.start(fn -> DiscoveryApi.Stats.QueryStats.record("failed:#{dataset_name}", duration_ms) end)  # ADD
      render_error(conn, 404, error)

    _ ->
      render_error(conn, 400, "Bad Request")
  end
rescue
  error in [Prestige.BadRequestError, Prestige.ConnectionError, Prestige.Error] ->   # ADD rescue
    duration_ms = System.monotonic_time(:millisecond) - conn.assigns.query_start_ms
    Task.start(fn -> DiscoveryApi.Stats.QueryStats.record("failed:#{dataset_name}", duration_ms) end)
    Logger.error("Query failed in DataController: #{inspect(error)}")
    render_error(conn, 400, PrestoService.sanitize_error(error.message, "Query Error"))
end
```

> `dataset_name` is safe to use in `rescue` in Elixir 1.14 — the OTP23 workaround
> using `conn.assigns.model.systemName` is not needed here.

### `multiple_data_controller.ex` — add wrap_stream and failure timing

**Diff from current OTP25 `query/2`:**

```elixir
def query(conn, _params) do
  conn = assign(conn, :query_start_ms, System.monotonic_time(:millisecond))   # ADD
  with {:ok, statement, conn} <- read_body(conn),
       {:ok, affected_models} <- QueryAccessUtils.get_affected_models(statement),
       {:ok, session} <- QueryAccessUtils.authorized_session(conn, affected_models) do
    Logger.info("Query request - statement: #{inspect(statement)}, affected_models: #{length(affected_models)}")

    Enum.each(affected_models, fn model ->
      Brook.Event.send(DiscoveryApi.instance_name(), dataset_query(), __MODULE__, model.id)
    end)

    format = get_format(conn)

    data_stream =
      @prestige_impl.stream!(session, statement)
      |> Stream.flat_map(&@prestige_result_impl.as_maps/1)
      |> DiscoveryApi.Stats.QueryStats.wrap_stream(statement)                  # ADD

    rendered_data_stream = MultipleDataView.render_as_stream(:data, format, %{stream: data_stream})
    resp_as_stream(conn, rendered_data_stream, format)
  else
    {:sql_error, error} ->
      duration_ms = System.monotonic_time(:millisecond) - conn.assigns.query_start_ms  # ADD
      Task.start(fn -> DiscoveryApi.Stats.QueryStats.record("failed:multi", duration_ms) end)  # ADD
      Logger.error("Query failed - SQL error: #{inspect(error)}")
      render_error(conn, 400, error)

    # ... other else branches unchanged ...
  end
rescue
  error in [Prestige.BadRequestError, Prestige.ConnectionError, Prestige.Error] ->   # ADD ConnectionError
    duration_ms = System.monotonic_time(:millisecond) - conn.assigns.query_start_ms  # ADD
    Task.start(fn -> DiscoveryApi.Stats.QueryStats.record("failed:multi", duration_ms) end)  # ADD
    Logger.error("Query failed - Prestige error: #{inspect(error)}, message: #{error.message}")
    render_error(conn, 400, PrestoService.sanitize_error(error.message, "Query Error"))
end
```

## Test changes

### `query_stats_test.exs` (new file)

There is no existing test file for QueryStats. The tests follow the Mox pattern:

```elixir
defmodule DiscoveryApi.Stats.QueryStatsTest do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!
  setup :set_mox_from_context

  alias DiscoveryApi.Stats.QueryStats

  setup do
    stub(RedixMock, :command, fn :redix, ["GET", _] -> {:ok, nil} end)
    :ok
  end

  test "records a query and returns stats" do
    {:ok, _pid} = start_supervised(QueryStats)
    QueryStats.record("SELECT 1", 100)
    stats = QueryStats.stats()

    assert stats.total_query_count == 1
    assert stats.unique_query_count == 1
    assert stats.overall_avg_duration_ms == 100.0
    assert stats.cache_hits == 0
    assert stats.cache_misses == 0
    assert stats.cache_hit_ratio == 0.0
  end
end
```

### Controller tests — `RedixMock` stub for cache calls

In any controller test that exercises the query path, add a `RedixMock` stub
to handle the `GET` calls that `QueryStats.stats/0` issues for cache counters.
Add to the `setup` block:

```elixir
stub(RedixMock, :command, fn :redix, _ -> {:ok, nil} end)
```

This returns nil for all `GET` calls (cache counters = 0) and is a no-op for
any `SET` / `INCR` calls since we ignore their return values.

## Apply to hot services

The compilation order and `patch_discovery_api_pod.sh` script are identical to
the OTP23 procedure. The `c/1` approach works the same way in OTP25 compiled
releases.

**1. Start the QueryStats process**

```elixir
Supervisor.start_child(DiscoveryApi.Supervisor, DiscoveryApi.Stats.QueryStats)
```

**2. Compile in order** (paste from `/tmp/task1.txt` generated by the patch script)

```elixir
c "/tmp/patch/apps/discovery_api/lib/discovery_api/stats/query_stats.ex"
c "/tmp/patch/apps/discovery_api/lib/discovery_api/services/metrics_service.ex"
c "/tmp/patch/apps/discovery_api/lib/discovery_api/services/presto_service.ex"
c "/tmp/patch/apps/discovery_api/lib/discovery_api_web/controllers/data_controller.ex"
c "/tmp/patch/apps/discovery_api/lib/discovery_api_web/controllers/multiple_data_controller.ex"
```

**3. Add Quantum jobs manually**

`config.exs` is read only at boot. Add jobs to the running scheduler:

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

**4. Verify**

```elixir
# Confirm the agent is running
Process.whereis(DiscoveryApi.Stats.QueryStats)

# Inject a fake query and trigger a flush
DiscoveryApi.Stats.QueryStats.record("SELECT 1", 100)
DiscoveryApi.Services.MetricsService.flush_query_stats_to_redis()
```

Then from Redis CLI: `GET discovery_api:query_stats`

## Troubleshooting

All troubleshooting steps from `discovery_query_stats.md` apply. Additional
OTP25-specific note:

### `@redix_module` resolves to `RedixMock` in production

If `Application.compile_env(:discovery_api, :redix_module, Redix)` resolves
to something unexpected in production, verify that `config/runtime.exs` or
the release config does not accidentally set `:redix_module`. In production it
should not be set (the default `Redix` applies). In test it must be
`RedixMock` (already set in `config/test.exs`).

### `c/1` resolves `@redix_module` to the production value

When compiling with `c "/tmp/patch/..."` in a running release console, the
`Application.compile_env` call reads the live application environment, which
in production resolves to `Redix`. This is the correct behavior. No action
needed.

---

## Caller stats by API key (amendment)

These changes add per-`api_key` request counting to the existing `QueryStats`
agent and surface it in the 5-minute Redis flush. They build on top of all the
changes described above and must be applied after `query_stats.ex`,
`query_cache.ex`, and the controller changes are in place.

### What changes

| File | Change |
|---|---|
| `stats/query_stats.ex` | Add `caller_counts: %{}` to state; add `record_caller/1` function; include `caller_counts` in `stats/0` return |
| `services/metrics_service.ex` | Add `unique_callers=N` to the flush log line |
| `controllers/data_controller.ex` | Call `record_caller/1` on every successful query |
| `controllers/multiple_data_controller.ex` | Call `record_caller/1` on every successful query |

### `query_stats.ex` — add `record_caller/1`

Add the function after `record/2` and include `caller_counts` in `initial_state/0`
and `stats/0`. The `@redix_module` attribute is unchanged from the base implementation.

```elixir
# In initial_state/0 — add caller_counts field
defp initial_state do
  %{query_data: %{}, total_count: 0, total_duration_ms: 0, caller_counts: %{}}
end

# New function — add after record/2
def record_caller(caller_id) do
  Agent.update(__MODULE__, fn state ->
    %{state | caller_counts: Map.update(state.caller_counts, caller_id, 1, &(&1 + 1))}
  end)
end

# In stats/0 — add caller_counts to the Agent.get return map
%{
  unique_query_count: map_size(state.query_data),
  total_query_count: state.total_count,
  overall_avg_duration_ms: overall_avg,
  per_query_avg_duration_ms: per_query_avgs,
  caller_counts: state.caller_counts          # <-- add this line
}
```

### `metrics_service.ex` — log unique caller count

Update the `Logger.info` call in `flush_query_stats_to_redis/0`:

```elixir
Logger.info(
  "Query stats flushed to Redis — unique=#{stats.unique_query_count} total=#{stats.total_query_count}" <>
    " overall_avg_ms=#{Float.round(stats.overall_avg_duration_ms, 2)}" <>
    " cache_hits=#{stats.cache_hits} cache_misses=#{stats.cache_misses} hit_ratio=#{stats.cache_hit_ratio}" <>
    " unique_callers=#{map_size(stats.caller_counts)}"   # <-- add this line
)
```

`caller_counts` is already included in the `stats` map, so it is automatically
serialized into `discovery_api:query_stats` in Redis with no other changes to
`flush_query_stats_to_redis/0`.

### `data_controller.ex` — record caller on success

`api_key` is already bound at line 81 as a list (`Plug.Conn.get_req_header`
returns `[]` or `["value"]`). Add the `record_caller` call immediately after
the `with` pipeline succeeds, before building `data_stream`:

```elixir
with {:ok, columns} <- @presto_service_impl.get_column_names(session, dataset_name, Map.get(params, "columns")),
     {:ok, query} <- @presto_service_impl.build_query(params, dataset_name, columns, schema),
     {:ok, affected_models} <- QueryAccessUtils.get_affected_models(query),
     true <- QueryAccessUtils.user_is_authorized?(affected_models, current_user, api_key) do
  caller_id = List.first(api_key) || "anonymous"                                        # ADD
  Task.start(fn -> DiscoveryApi.Stats.QueryStats.record_caller(caller_id) end)          # ADD

  data_stream =
    session
    |> @prestige_impl.stream!(query)
    ...
```

> `api_key` is a list here (not a scalar). `List.first/1` returns `nil` for
> unauthenticated requests; the `|| "anonymous"` fallback groups those together.

### `multiple_data_controller.ex` — record caller on success

The `api_key` header is not pre-bound in this controller. Read it inline in the
success branch:

```elixir
with {:ok, statement, conn} <- read_body(conn),
     {:ok, affected_models} <- QueryAccessUtils.get_affected_models(statement),
     {:ok, session} <- QueryAccessUtils.authorized_session(conn, affected_models) do
  caller_id = Plug.Conn.get_req_header(conn, "api_key") |> List.first() || "anonymous"  # ADD
  Task.start(fn -> DiscoveryApi.Stats.QueryStats.record_caller(caller_id) end)           # ADD

  Logger.info("Query request - statement: #{inspect(statement)}, affected_models: #{length(affected_models)}")
  ...
```

### Reading the stats

```elixir
# Full map including caller breakdown
DiscoveryApi.Stats.QueryStats.stats()

# Just the per-caller counts
DiscoveryApi.Stats.QueryStats.stats().caller_counts
# => %{"abc123apikey" => 42, "def456apikey" => 7, "anonymous" => 3}
```

The `caller_counts` map is also serialized into `discovery_api:query_stats` on
the existing 5-minute flush, so it is readable from Redis CLI:

```
GET discovery_api:query_stats
```

### Hot-patching the running pod

Recompile in this order (the caller stats changes touch four modules):

```elixir
c "/tmp/patch/apps/discovery_api/lib/discovery_api/stats/query_stats.ex"
c "/tmp/patch/apps/discovery_api/lib/discovery_api/services/metrics_service.ex"
c "/tmp/patch/apps/discovery_api/lib/discovery_api_web/controllers/data_controller.ex"
c "/tmp/patch/apps/discovery_api/lib/discovery_api_web/controllers/multiple_data_controller.ex"
```

`query_stats.ex` must be compiled first because the controllers call
`DiscoveryApi.Stats.QueryStats.record_caller/1` — if the controllers are
compiled before the function exists the BEAM will raise an `UndefinedFunctionError`
on the first request.

After recompiling, verify with:

```elixir
# Should return %{..., caller_counts: %{}}
DiscoveryApi.Stats.QueryStats.stats()
```
