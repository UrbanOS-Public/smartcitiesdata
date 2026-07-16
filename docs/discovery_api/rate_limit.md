# Discovery API — Rate Limiting by API Key

Rate limiting constrains how many requests a given `api_key` can make within a
rolling time window. The approach described here uses the Redis INCR + EXPIRE
fixed-window pattern, which is consistent with how `record_api_hit` already
works in this codebase and requires no new dependencies.

## Approach

A new `RateLimit` plug reads the `api_key` request header, increments a
per-key Redis counter scoped to the current time window, and halts with HTTP
429 if the counter exceeds the configured limit. The plug sits in the request
pipeline after `verify_token` (so the key is present) and before controllers
do any real work.

### Fixed-window vs. sliding-window tradeoff

| | Fixed window (this approach) | Hammer library (sliding window) |
|---|---|---|
| Dependencies | None (uses existing Redix) | Adds `hammer` + `hammer_backend_redis` |
| Edge case | Up to 2× limit possible at window boundary | Accurate at all times |
| Complexity | Low | Moderate |

The fixed-window approach is sufficient for protecting against runaway clients.
Use Hammer if precise per-second fairness is required.

## Files to change

| File | Change |
|---|---|
| `apps/discovery_api/lib/discovery_api_web/plugs/rate_limit.ex` | New plug |
| `apps/discovery_api/lib/discovery_api_web/router.ex` | Add plug to pipeline |
| `apps/discovery_api/config/config.exs` | Add rate limit config |

## Implementation

### `plugs/rate_limit.ex` (new file)

```elixir
defmodule DiscoveryApiWeb.Plugs.RateLimit do
  import Plug.Conn

  @default_limit 100
  @window_seconds 60

  def init(opts), do: opts

  def call(conn, _opts) do
    limit =
      Application.get_env(:discovery_api, :rate_limit, [])
      |> Keyword.get(:requests_per_minute, @default_limit)

    case get_req_header(conn, "api_key") |> List.first() do
      nil -> conn  # no api_key — let auth plug handle it
      key -> check_limit(conn, key, limit)
    end
  end

  defp check_limit(conn, api_key, limit) do
    window = div(System.os_time(:second), @window_seconds)
    redis_key = "discovery_api:rate_limit:#{api_key}:#{window}"

    {:ok, count} = Redix.command(:redix, ["INCR", redis_key])

    if count == 1 do
      Redix.command(:redix, ["EXPIRE", redis_key, @window_seconds * 2])
    end

    if count > limit do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(429, Jason.encode!(%{message: "Rate limit exceeded"}))
      |> halt()
    else
      conn
    end
  end
end
```

The EXPIRE is set to `@window_seconds * 2` (120 s for a 60 s window) so the
key outlives the window long enough for the boundary overlap but does not
accumulate indefinitely.

### `router.ex` — add plug to pipeline

Add `RateLimit` inside the `:add_user_details` pipeline, after `SetCurrentUser`
so that the `api_key` header has been validated, and before requests reach any
controller:

```elixir
pipeline :add_user_details do
  plug DiscoveryApiWeb.Plugs.SetCurrentUser
  plug DiscoveryApiWeb.Plugs.RateLimit    # <-- add here
end
```

### `config/config.exs` — add rate limit config

```elixir
config :discovery_api, :rate_limit,
  requests_per_minute: 100
```

Adjust `requests_per_minute` to suit expected client volumes. The value is read
at request time via `Application.get_env/3` so it can be overridden in
`config/runtime.exs` or environment-specific config files without recompiling.

## Redis key format

```
discovery_api:rate_limit:<api_key>:<window_number>
```

`window_number` is `unix_timestamp div 60`, so it increments once per minute.
Keys expire automatically after 120 seconds and do not need manual cleanup.

## Open question — JWT-authenticated requests

Requests authenticated via JWT (no `api_key` header) return `nil` from
`List.first/1` and are currently passed through without rate limiting. If those
requests also need to be limited, two options:

1. **Key by IP** — use `conn.remote_ip` as the fallback identifier when no
   `api_key` is present.
2. **Key by user ID** — move the plug to run after `SetCurrentUser` resolves
   the Guardian resource, and use `conn.assigns.current_user` as the key.
   This requires the plug to be declared after `SetCurrentUser` in the pipeline
   (already the case above).

Either approach can be added to `check_limit/3` as a second function head
without changing the api_key path.

## OTP25 notes

In the OTP25 codebase, replace the direct `Redix.command/2` calls with the
module attribute pattern used throughout that codebase:

```elixir
@redix_module Application.compile_env(:discovery_api, :redix_module, Redix)

# then:
{:ok, count} = @redix_module.command(:redix, ["INCR", redis_key])
@redix_module.command(:redix, ["EXPIRE", redis_key, @window_seconds * 2])
```

Add to `config/test.exs`:

```elixir
stub(RedixMock, :command, fn :redix, ["INCR", _] -> {:ok, 1} end)
```
