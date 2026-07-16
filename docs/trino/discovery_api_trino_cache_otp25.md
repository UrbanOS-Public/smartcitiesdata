# Discovery API — Trino Query Cache (OTP25)

This document covers the OTP25/Elixir 1.14.4 implementation. The conceptual
background (cache key format, TTL, hit/miss counters, Redis inspection commands)
is identical to `discovery_api_trino_cache.md`. Read that document first. This
document focuses on what is **different** in the OTP25 codebase.

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

### 1. Redix is injected via `@redix_module`

OTP25 modules call Redis through a compile-time module attribute (matching
`persistence.ex`). This allows the existing `RedixMock` Mox mock to intercept
Redis calls in tests automatically:

```elixir
@redix_module Application.compile_env(:discovery_api, :redix_module, Redix)
```

`config/test.exs` already sets `redix_module: RedixMock`, so no additional
test configuration is needed.

### 2. Prestige 3.x — materialization pattern is the same

`Prestige.stream!/2` still returns a lazy `Enumerable.t()`. On a cache miss,
the stream must be fully consumed with `Enum.to_list/1` before serialization,
exactly as in OTP23. The only syntactic difference is that OTP25 code passes
session as the first positional argument rather than piping:

```elixir
# OTP25 — via module attribute, session is first arg
@prestige_impl.stream!(session, query) |> Stream.flat_map(...) |> Enum.to_list()

# OTP23 — piped
session |> Prestige.stream!(query) |> Stream.flat_map(...) |> Enum.to_list()
```

### 3. Error types include `Prestige.BadRequestError`

OTP25 rescue clauses must include `Prestige.BadRequestError`:

```elixir
rescue
  error in [Prestige.BadRequestError, Prestige.ConnectionError, Prestige.Error] ->
```

### 4. `get_column_names/3` not `get_column_names_from_schema/3`

The OTP25 `PrestoService` exposes `get_column_names/3` (fetches from Trino
schema). There is no `get_column_names_from_schema/3` function.

### 5. Tests use Mox, not Placebo

Replace `use Placebo` / `allow(...)` / `assert_called(...)` with Mox patterns:

```elixir
use ExUnit.Case
import Mox
setup :verify_on_exit!
setup :set_mox_from_context

stub(RedixMock, :command, fn :redix, _ -> {:ok, nil} end)
expect(RedixMock, :command, fn :redix, ["INCR", "discovery_api:trino_cache:hits"] -> {:ok, 1} end)
```

## Modified files

| File | Change |
|---|---|
| `apps/discovery_api/lib/discovery_api/services/query_cache.ex` | New — `@redix_module` attribute; cache key, GET/SETEX, hit/miss INCR counters |
| `apps/discovery_api/lib/discovery_api/services/metrics_service.ex` | `@redix_module` attribute; `flush_query_stats_to_redis/0` via `QueryStats.stats/0` |
| `apps/discovery_api/lib/discovery_api_web/controllers/data_controller.ex` | `query/2` — `QueryCache.fetch_or_execute/2` wrapping `@prestige_impl.stream!` |
| `apps/discovery_api/lib/discovery_api_web/controllers/multiple_data_controller.ex` | `query/2` — same pattern as `DataController` |
| `apps/discovery_api/config/config.exs` | `config :discovery_api, :query_cache, max_rows: 50_000` |

## Code changes

### `query_cache.ex` (new file)

```elixir
defmodule DiscoveryApi.Services.QueryCache do
  @moduledoc false

  @redix_module Application.compile_env(:discovery_api, :redix_module, Redix)
  @prefix "discovery_api:trino_cache:"
  @ttl_seconds 360
  @hits_key "discovery_api:trino_cache:hits"
  @misses_key "discovery_api:trino_cache:misses"

  def cache_key(query_string) do
    hash = :crypto.hash(:md5, query_string) |> Base.encode16()
    @prefix <> hash
  end

  # Returns {:ok, rows, :cache_hit | :cache_miss} or the raw error from execute_fn.
  # Redis failures degrade gracefully — they never prevent query execution.
  def fetch_or_execute(query_string, execute_fn) do
    key = cache_key(query_string)

    case get_cached(key) do
      {:ok, rows} ->
        @redix_module.command(:redix, ["INCR", @hits_key])
        {:ok, rows, :cache_hit}

      :miss ->
        case execute_fn.() do
          {:ok, rows} ->
            store(key, rows)
            @redix_module.command(:redix, ["INCR", @misses_key])
            {:ok, rows, :cache_miss}

          error ->
            error
        end
    end
  end

  defp get_cached(key) do
    case @redix_module.command(:redix, ["GET", key]) do
      {:ok, nil} ->
        :miss

      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, rows} -> {:ok, rows}
          _ -> :miss
        end

      _ ->
        :miss
    end
  end

  defp store(key, rows) do
    max = Application.get_env(:discovery_api, :query_cache, []) |> Keyword.get(:max_rows, 50_000)

    if length(rows) <= max do
      case Jason.encode(rows) do
        {:ok, json} -> @redix_module.command(:redix, ["SETEX", key, @ttl_seconds, json])
        _ -> :noop
      end
    end
  end
end
```

### `data_controller.ex` — integrate QueryCache

Add the alias and update `query/2`. The changes are confined to the `with`
chain and `else`/`rescue` blocks. Unchanged sections are marked with `# ...`:

```elixir
defmodule DiscoveryApiWeb.DataController do
  # ... existing use / alias / plug / getter declarations ...

  alias DiscoveryApi.Services.{PrestoService, QueryCache}   # ADD QueryCache

  # ...

  def query(conn, params) do
    conn = assign(conn, :query_start_ms, System.monotonic_time(:millisecond))
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
         true <- QueryAccessUtils.user_is_authorized?(affected_models, current_user, api_key),
         {:ok, rows, _} <- QueryCache.fetch_or_execute(query, fn ->         # REPLACE stream pipeline
           fetched =
             @prestige_impl.stream!(session, query)
             |> Stream.flat_map(&@prestige_result_impl.as_maps/1)
             |> Enum.to_list()
           {:ok, fetched}
         end) do
      data_stream =
        rows
        |> map_schema?(schema, format)
        |> DiscoveryApi.Stats.QueryStats.wrap_stream(query)

      rendered_data_stream =
        DataView.render_as_stream(:data, format, %{stream: data_stream, columns: columns, dataset_name: dataset_name, schema: schema})

      resp_as_stream(conn, rendered_data_stream, format, dataset_id)
    else
      {:error, error} ->
        duration_ms = System.monotonic_time(:millisecond) - conn.assigns.query_start_ms
        Task.start(fn -> DiscoveryApi.Stats.QueryStats.record("failed:#{dataset_name}", duration_ms) end)
        render_error(conn, 404, error)

      _ ->
        render_error(conn, 400, "Bad Request")
    end
  rescue
    error in [Prestige.BadRequestError, Prestige.ConnectionError, Prestige.Error] ->
      duration_ms = System.monotonic_time(:millisecond) - conn.assigns.query_start_ms
      Task.start(fn -> DiscoveryApi.Stats.QueryStats.record("failed:#{dataset_name}", duration_ms) end)
      Logger.error("Query failed in DataController: #{inspect(error)}")
      render_error(conn, 400, PrestoService.sanitize_error(error.message, "Query Error"))
  end
```

### `multiple_data_controller.ex` — integrate QueryCache

```elixir
defmodule DiscoveryApiWeb.MultipleDataController do
  # ... existing declarations ...

  alias DiscoveryApi.Services.{PrestoService, QueryCache}   # ADD QueryCache

  # ...

  def query(conn, _params) do
    conn = assign(conn, :query_start_ms, System.monotonic_time(:millisecond))
    with {:ok, statement, conn} <- read_body(conn),
         {:ok, affected_models} <- QueryAccessUtils.get_affected_models(statement),
         {:ok, session} <- QueryAccessUtils.authorized_session(conn, affected_models),
         {:ok, rows, _} <- QueryCache.fetch_or_execute(statement, fn ->     # ADD cache layer
           fetched =
             @prestige_impl.stream!(session, statement)
             |> Stream.flat_map(&@prestige_result_impl.as_maps/1)
             |> Enum.to_list()
           {:ok, fetched}
         end) do
      Logger.info("Query request - statement: #{inspect(statement)}, affected_models: #{length(affected_models)}")

      Enum.each(affected_models, fn model ->
        Brook.Event.send(DiscoveryApi.instance_name(), dataset_query(), __MODULE__, model.id)
      end)

      format = get_format(conn)

      data_stream =
        rows
        |> Stream.map(& &1)
        |> DiscoveryApi.Stats.QueryStats.wrap_stream(statement)

      rendered_data_stream = MultipleDataView.render_as_stream(:data, format, %{stream: data_stream})
      resp_as_stream(conn, rendered_data_stream, format)
    else
      {:error, :invalid_statement} ->
        Logger.error("Query failed - invalid statement")
        render_error(conn, 400, "Invalid SQL statement")

      {:error, :table_not_found} ->
        Logger.error("Query failed - table not found")
        render_error(conn, 400, "Table not found")

      {:error, "Query statement is invalid" <> _rest = error_msg} ->
        Logger.error("Query failed - #{error_msg}")
        render_error(conn, 400, "Bad Request")

      {:sql_error, error} ->
        duration_ms = System.monotonic_time(:millisecond) - conn.assigns.query_start_ms
        Task.start(fn -> DiscoveryApi.Stats.QueryStats.record("failed:multi", duration_ms) end)
        Logger.error("Query failed - SQL error: #{inspect(error)}")
        render_error(conn, 400, error)

      {:error, "Session not authorized" = error_msg} ->
        Logger.error("Query failed - #{error_msg}")
        render_error(conn, 400, "Bad Request")

      {:error, reason} ->
        Logger.error("Query failed - error: #{inspect(reason)}")
        render_error(conn, 400, "Bad Request")

      other ->
        Logger.error("Query failed - unexpected error: #{inspect(other)}")
        render_error(conn, 400, "Bad Request")
    end
  rescue
    error in [Prestige.BadRequestError, Prestige.ConnectionError, Prestige.Error] ->
      duration_ms = System.monotonic_time(:millisecond) - conn.assigns.query_start_ms
      Task.start(fn -> DiscoveryApi.Stats.QueryStats.record("failed:multi", duration_ms) end)
      Logger.error("Query failed - Prestige error: #{inspect(error)}, message: #{error.message}")
      render_error(conn, 400, PrestoService.sanitize_error(error.message, "Query Error"))
  end
end
```

> `MultipleDataController` now materializes rows to a list. The `Stream.map(& &1)`
> line converts the list back to a stream so `wrap_stream/2` and the view
> pipeline receive an `Enumerable.t()`. A plain list would also work since both
> are Enumerable, but the explicit conversion makes the intent clear.

### `config/config.exs` — add query_cache config

```elixir
config :discovery_api, :query_cache,
  max_rows: 50_000
```

The Quantum jobs are added as part of the query stats change (see
`discovery_query_stats_otp25.md`).

## Test changes

### `query_cache_test.exs` (new file)

```elixir
defmodule DiscoveryApi.Services.QueryCacheTest do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!
  setup :set_mox_from_context

  alias DiscoveryApi.Services.QueryCache

  @query "SELECT id, name FROM test_table"
  @rows [%{"id" => 1, "name" => "Alice"}, %{"id" => 2, "name" => "Bob"}]

  describe "cache_key/1" do
    test "is prefixed with discovery_api:trino_cache:" do
      assert String.starts_with?(QueryCache.cache_key(@query), "discovery_api:trino_cache:")
    end

    test "is deterministic for the same query" do
      assert QueryCache.cache_key(@query) == QueryCache.cache_key(@query)
    end

    test "differs for different queries" do
      refute QueryCache.cache_key(@query) == QueryCache.cache_key("SELECT * FROM other")
    end
  end

  describe "fetch_or_execute/2 — cache hit" do
    test "returns cached rows and :cache_hit without calling execute_fn" do
      stub(RedixMock, :command, fn :redix, ["GET", _] -> {:ok, Jason.encode!(@rows)} end)
      expect(RedixMock, :command, fn :redix, ["INCR", "discovery_api:trino_cache:hits"] -> {:ok, 1} end)

      result = QueryCache.fetch_or_execute(@query, fn -> raise "should not be called" end)

      assert {:ok, @rows, :cache_hit} == result
    end
  end

  describe "fetch_or_execute/2 — cache miss" do
    test "calls execute_fn, writes SETEX, and returns :cache_miss" do
      stub(RedixMock, :command, fn
        :redix, ["GET", _] -> {:ok, nil}
        :redix, ["SETEX" | _] -> {:ok, "OK"}
        :redix, ["INCR", _] -> {:ok, 1}
      end)

      assert {:ok, @rows, :cache_miss} == QueryCache.fetch_or_execute(@query, fn -> {:ok, @rows} end)
    end

    test "skips SETEX when row count exceeds max_rows" do
      Application.put_env(:discovery_api, :query_cache, max_rows: 1)
      on_exit(fn -> Application.delete_env(:discovery_api, :query_cache) end)

      stub(RedixMock, :command, fn
        :redix, ["GET", _] -> {:ok, nil}
        :redix, ["INCR", _] -> {:ok, 1}
      end)

      assert {:ok, @rows, :cache_miss} == QueryCache.fetch_or_execute(@query, fn -> {:ok, @rows} end)
    end

    test "propagates execute_fn error tuple without writing to Redis" do
      stub(RedixMock, :command, fn :redix, ["GET", _] -> {:ok, nil} end)

      assert {:error, "trino down"} == QueryCache.fetch_or_execute(@query, fn -> {:error, "trino down"} end)
    end
  end

  describe "fetch_or_execute/2 — Redis failures" do
    test "treats a Redis GET error as a cache miss and still executes" do
      stub(RedixMock, :command, fn
        :redix, ["GET", _] -> {:error, :econnrefused}
        :redix, ["SETEX" | _] -> {:ok, "OK"}
        :redix, ["INCR", _] -> {:ok, 1}
      end)

      assert {:ok, @rows, :cache_miss} == QueryCache.fetch_or_execute(@query, fn -> {:ok, @rows} end)
    end

    test "does not raise when Redis SETEX fails" do
      stub(RedixMock, :command, fn
        :redix, ["GET", _] -> {:ok, nil}
        :redix, ["SETEX" | _] -> {:error, :econnrefused}
        :redix, ["INCR", _] -> {:ok, 1}
      end)

      assert {:ok, @rows, :cache_miss} == QueryCache.fetch_or_execute(@query, fn -> {:ok, @rows} end)
    end

    test "treats malformed cached JSON as a cache miss" do
      stub(RedixMock, :command, fn
        :redix, ["GET", _] -> {:ok, "not valid json {"}
        :redix, ["SETEX" | _] -> {:ok, "OK"}
        :redix, ["INCR", _] -> {:ok, 1}
      end)

      assert {:ok, @rows, :cache_miss} == QueryCache.fetch_or_execute(@query, fn -> {:ok, @rows} end)
    end
  end
end
```

### Controller tests — add `RedixMock` cache stub

In `data_controller_query_test.exs` and `multiple_data_controller_test.exs`,
add a stub in the shared `setup` block to handle the GET and INCR calls that
`QueryCache.fetch_or_execute/2` issues:

```elixir
setup do
  # ... existing stubs ...

  # Simulate a cache miss on every request (no cached entry)
  stub(RedixMock, :command, fn :redix, _ -> {:ok, nil} end)

  :ok
end
```

This returns `{:ok, nil}` for GET (cache miss), ignores SETEX and INCR return
values — matching the `RedixMock.command!/2` stub already present for the
`smart_registry` INCR calls.

## Apply to hot services

The patch script and compilation order are identical to the OTP23 procedure.
Use `patch_discovery_api_pod.sh` to copy files into the pod and generate
`/tmp/task1.txt`.

**Compile in IEx in this order** (`query_cache.ex` must precede controllers):

```elixir
c "/tmp/patch/apps/discovery_api/lib/discovery_api/stats/query_stats.ex"
c "/tmp/patch/apps/discovery_api/lib/discovery_api/services/query_cache.ex"
c "/tmp/patch/apps/discovery_api/lib/discovery_api/services/metrics_service.ex"
c "/tmp/patch/apps/discovery_api/lib/discovery_api/services/presto_service.ex"
c "/tmp/patch/apps/discovery_api/lib/discovery_api_web/controllers/data_controller.ex"
c "/tmp/patch/apps/discovery_api/lib/discovery_api_web/controllers/multiple_data_controller.ex"
```

**Apply the `max_rows` config at runtime** (since `config.exs` cannot be
hot-reloaded, and the default 50,000 is hardcoded as fallback in
`QueryCache.store/2`):

```elixir
Application.put_env(:discovery_api, :query_cache, max_rows: 50_000)
```

**Verify the cache is active** — send a query twice and check:

```elixir
# From IEx
key = DiscoveryApi.Services.QueryCache.cache_key("SELECT id FROM some_table")
Redix.command(:redix, ["EXISTS", key])
# {:ok, 1} means the entry is present
```

Or from Redis CLI: `KEYS discovery_api:trino_cache:*`

## Important: `@redix_module` resolves at compile time

When using `c/1` in a running production release, `Application.compile_env/3`
reads the **live** application environment. In production (no `:redix_module`
config key), this resolves to `Redix` — the real module. This is correct.

Do not set `:redix_module` in production configs or runtime.exs. It is a
test-only override.

## Troubleshooting

All troubleshooting from `discovery_api_trino_cache.md` applies. Additional
OTP25 notes:

### `@redix_module` undefined error after `c/1`

If compilation fails with `undefined function @redix_module.command/2`, ensure
the source file being compiled contains the `@redix_module` module attribute
definition at the top of the module body. If patching from an OTP23 source
file (which calls `Redix.command` directly), you must update the source to
use `@redix_module` before copying to the pod.

### Prestige.BadRequestError not matched in rescue

If a `Prestige.BadRequestError` leaks past the rescue clause, the rescue list
is missing the error type. In Prestige 3.x, `BadRequestError` is raised for
HTTP 4xx responses from Trino (e.g. syntax errors). Ensure all three types are
listed:

```elixir
rescue
  error in [Prestige.BadRequestError, Prestige.ConnectionError, Prestige.Error] ->
```
