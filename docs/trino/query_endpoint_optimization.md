# Query Endpoint Optimization: Eliminating Redundant DESCRIBE Calls

## Background

Every request to `GET /api/v1/organization/:org/dataset/:name/query` (and
`/api/v1/dataset/:id/query`) previously fired a `DESCRIBE <table>` query
against Trino before executing the actual SELECT. This doubled Trino query
queue pressure under normal load and was a primary contributor to
`QUERY_QUEUE_FULL` errors during burst traffic (e.g. post-Redis-flush recovery,
or sustained polling from external clients).

## Root Cause

`DiscoveryApi.Services.PrestoService.get_column_names/2` was called at the top
of `DataController.query/2` to obtain the column list for the SELECT clause:

```elixir
# data_controller.ex — original
with {:ok, columns} <- PrestoService.get_column_names(session, dataset_name, Map.get(params, "columns")),
```

`get_column_names/2` issued:

```elixir
Prestige.query!("describe #{system_name}")
```

…collected the column names from the result, then **immediately discarded**
the three Forklift-internal columns added at write time:

```elixir
@metadata_columns ["_extraction_start_time", "_ingestion_id", "os_partition"]
```

The resulting column list is identical to the field names in `model.schema`,
which is already loaded into `conn.assigns.model` by the `GetModel` plug from
Brook/Redis — **before the controller runs, with no network roundtrip**.

## The Fix

### `presto_service.ex`

Added a module attribute to centralise the metadata column list (previously
hardcoded inline):

```elixir
@metadata_columns ["_extraction_start_time", "_ingestion_id", "os_partition"]
```

Added a new public function that derives column names from the already-loaded
Andi schema instead of querying Trino:

```elixir
def get_column_names_from_schema(schema, nil) do
  names = schema |> Enum.map(& &1.name) |> Enum.reject(&(&1 in @metadata_columns))
  {:ok, names}
end

def get_column_names_from_schema(_schema, columns_string) do
  {:ok, clean_columns(columns_string)}
end
```

The existing `get_column_names/2,3` functions (which call `DESCRIBE`) were
**kept** — they are still valid for use from other call sites (e.g. Tableau
controller, tests, IEx diagnostics).

### `data_controller.ex`

Switched the `query/2` action to call the schema-based function:

```elixir
# before
with {:ok, columns} <- PrestoService.get_column_names(session, dataset_name, Map.get(params, "columns")),

# after
with {:ok, columns} <- PrestoService.get_column_names_from_schema(schema, Map.get(params, "columns")),
```

Added a `rescue` block for `Prestige.Error` to handle the case where Trino
rejects the actual SELECT (e.g. table not yet created). Previously this was
surfaced as a 404 via the `DESCRIBE` failure; it now returns a 400:

```elixir
rescue
  error in Prestige.Error ->
    Logger.error("Query endpoint error for dataset #{dataset_name}: #{inspect(error)}")
    render_error(conn, 400, "Bad Request")
```

## Behaviour Change

| Scenario | Before | After |
|---|---|---|
| Normal query (no `?columns=`) | 1× DESCRIBE + actual query | actual query only |
| Query with `?columns=col1,col2` | 1× DESCRIBE (validate table) + actual query | actual query only |
| Table not in Trino yet | 404 via DESCRIBE failure | 400 via `Prestige.Error` rescue |

The 404→400 change for missing tables is acceptable: the table not existing in
Trino is not a "resource not found" condition from the API caller's perspective
(the dataset metadata was found; the underlying store isn't ready).

## Impact

- **Trino query queue pressure halved** for the `/query` endpoint under normal load.
- During burst traffic (post-Redis-flush resend, external polling clients),
  this is the difference between Trino staying within `query.max-queued-queries`
  and returning `QUERY_QUEUE_FULL` to every request.
- No change to response format, streaming behaviour, auth checks, or SQL
  injection validation.

## Applying to otp25

The same change applies verbatim. Verify these two files on the otp25 branch
first:

### Step 1 — `apps/discovery_api/lib/discovery_api/services/presto_service.ex`

1. Add the module attribute immediately after `@supported_statements`:
   ```elixir
   @metadata_columns ["_extraction_start_time", "_ingestion_id", "os_partition"]
   ```

2. Add the new function before `get_column_names/3`:
   ```elixir
   def get_column_names_from_schema(schema, nil) do
     names = schema |> Enum.map(& &1.name) |> Enum.reject(&(&1 in @metadata_columns))
     {:ok, names}
   end

   def get_column_names_from_schema(_schema, columns_string) do
     {:ok, clean_columns(columns_string)}
   end
   ```

3. Update the private `remove_metadata_columns/1` to use the attribute:
   ```elixir
   defp remove_metadata_columns(columns) do
     columns |> Enum.reject(fn column -> column in @metadata_columns end)
   end
   ```

### Step 2 — `apps/discovery_api/lib/discovery_api_web/controllers/data_controller.ex`

In `query/2`, replace the first line of the `with` expression and add a rescue:

```elixir
# Change:
with {:ok, columns} <- PrestoService.get_column_names(session, dataset_name, Map.get(params, "columns")),

# To:
with {:ok, columns} <- PrestoService.get_column_names_from_schema(schema, Map.get(params, "columns")),
```

Add after the `end` of the `with`/`else` block, before the closing `end` of `query/2`:

```elixir
rescue
  error in Prestige.Error ->
    Logger.error("Query endpoint error for dataset #{dataset_name}: #{inspect(error)}")
    render_error(conn, 400, "Bad Request")
```

### Verification

After deploying, confirm in discovery-api logs that `DESCRIBE` no longer
appears for `/query` requests. In Trino's `system.runtime.queries`, the query
count from the `discovery-api` user should drop by roughly half for endpoints
serving active polling clients.
