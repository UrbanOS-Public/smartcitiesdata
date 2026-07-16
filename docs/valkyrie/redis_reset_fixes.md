# Valkyrie Schema Validation Failures After Redis Reset

## Background

After a Redis flush and Brook view-state recovery (see [`docs/redis/post_flush.md`](../redis/post_flush.md)),
datasets with `map`-type fields in their schema may still fail Valkyrie schema validation even after
republishing via `Andi.Scripts.ResendEvents.resend_dataset_events/0`. Affected records are dead-lettered
with a reason like:

```
%{"deployed" => :invalid_type, "modified" => :invalid_type, "status" => :invalid_type}
```

These fields are defined as `type: "map"` in the ANDI data dictionary and carry valid JSON objects
in the payload. The validation failure is not a data problem — it is caused by two bugs: one in
Valkyrie's type-dispatch logic, one in how ANDI's `resend_dataset_events` serialises the schema.

---

## Root Cause

### Bug 1 — Valkyrie: missing pattern for `map` type without `:subSchema`

**File:** `apps/valkyrie/lib/valkyrie.ex`

Valkyrie validates each payload field by pattern-matching the schema field struct against a series
of `standardize/2` clauses. For `map`-type fields there were two clauses:

```elixir
# catches non-map values
defp standardize(%{type: "map"}, value) when not is_map(value) do
  {:error, :invalid_map}
end

# validates sub-fields when :subSchema key is present
defp standardize(%{type: "map", subSchema: sub_schema} = field, value) do
  ...
end
```

There was **no clause** for `%{type: "map"}` when the value *is* a map but the schema field
struct has **no `:subSchema` key**. Such fields fell through to the catch-all:

```elixir
defp standardize(_ss, _v) do
  {:error, :invalid_type}
end
```

An unstructured `map`-type field (one intentionally defined without sub-fields) always lacks
a `:subSchema` key, so Valkyrie always returned `:invalid_type` for its values regardless of
whether those values were valid JSON objects.

### Bug 2 — ANDI `resend_dataset_events`: `subSchema` not preloaded, so published schema has no `:subSchema` key

**File:** `apps/andi/lib/andi/scripts/resend_events.ex`

`resend_dataset_events/1` builds `SmartCity.Dataset` events from Postgres via `Datasets.get_all/0`:

```elixir
def get_all() do
  ...
  Repo.all(query)
  |> Repo.preload(technical: :schema)  # loads schema rows, but NOT their subSchema children
end
```

`Repo.preload(technical: :schema)` loads the top-level `DataDictionary` rows for each dataset
but leaves the nested `subSchema` association as `%Ecto.Association.NotLoaded{}`.

`StructTools.struct_to_map/1` (called inside `andi_dataset_to_smrt_dataset/1`) explicitly drops
`%Ecto.Association.NotLoaded{}` values:

```elixir
|> Enum.reject(fn
  {_k, %Ecto.Association.NotLoaded{}} -> true
  ...
end)
```

After `drop_fields_from_dictionary_item/1` runs, the `:subSchema` key is absent from every
published schema field. Valkyrie stores this schema in Brook/Redis. From that point on, **every
incoming record for any `map`-type field fails with `:invalid_type`** — including fields that
were working correctly before the flush.

By contrast, the normal ANDI UI publish path calls `Datasets.get/1`, which goes through
`Dataset.preload/1` → `Technical.preload/1` → `DataDictionary.preload([:subSchema])`, correctly
loading `subSchema` at every nesting level. But once a bad event from `resend_dataset_events`
lands in Valkyrie's Brook cache, subsequent UI publishes may not replace it if the event ordering
means the bad event arrives last.

---

## Fixes Applied

### Fix 1 — Valkyrie: add missing `map`-without-`subSchema` clause

**File:** `apps/valkyrie/lib/valkyrie.ex`

Added a new clause between the existing `subSchema`-present clause and the `list` clauses:

```elixir
# before: no clause — fell through to catch-all returning :invalid_type
# after:
defp standardize(%{type: "map"}, value) when is_map(value) do
  {:ok, value}
end
```

Pattern dispatch order (all four `map` clauses in order):

| Clause | Matches when |
|--------|-------------|
| `%{type: "map"}` + guard `not is_map(value)` | value is not a map → `:invalid_map` |
| `%{type: "map", subSchema: sub_schema}` | `:subSchema` key present → validate sub-fields recursively |
| `%{type: "map"}` + guard `is_map(value)` *(new)* | `:subSchema` key absent, value is a map → pass through |
| catch-all | anything else → `:invalid_type` |

This fix alone unblocks affected datasets — no dataset republish is needed after deploying
the updated Valkyrie. The schema already stored in Valkyrie's Brook/Redis (without `:subSchema`)
will correctly match the new clause.

### Fix 2 — ANDI: re-fetch each dataset with full preloading in `resend_dataset_events`

**File:** `apps/andi/lib/andi/scripts/resend_events.ex`

Changed `resend_dataset_events/1` to call `Datasets.get/1` on each published dataset ID after
the initial `get_all/0` filter. `Datasets.get/1` triggers the full preload chain
(`Dataset.preload` → `Technical.preload` → recursive `DataDictionary.preload([:subSchema])`),
ensuring every schema field — including nested map sub-fields — is present in the published event.

```elixir
# before
Datasets.get_all()
|> Enum.filter(&(&1.submission_status == :published))
|> Enum.each(fn andi_dataset -> ...)

# after
Datasets.get_all()
|> Enum.filter(&(&1.submission_status == :published))
|> Enum.map(& &1.id)
|> Enum.map(&Datasets.get/1)
|> Enum.each(fn andi_dataset -> ...)
```

This is an N+1 query (one `SELECT` per published dataset), which is acceptable given the
existing 500 ms inter-event sleep. The alternative — changing `Datasets.get_all/0` to use
`Repo.preload(technical: [schema: :subSchema])` — only loads one level of nesting and would
miss maps-within-maps.

---

## How to Detect This Issue

In Valkyrie logs, look for dead-letter entries where the failing fields are all defined as
`type: "map"` in the data dictionary:

```
[error] ingestion_id: <uuid>; payload: %{..., "deployed" => %{...}, ...};
        Failed Schema Validation: %{"deployed" => :invalid_type, ...}
```

Confirm the types are correct in ANDI Postgres:

```sql
SELECT dd.name, dd.type
  FROM data_dictionary dd
  JOIN technical t ON dd.technical_id = t.id
  WHERE t.dataset_id = '<dataset-id>'
    AND dd.name IN ('<field1>', '<field2>');
```

If the DB shows `type = 'map'` but Valkyrie reports `:invalid_type`, this bug is the cause.

---

## Deployment Notes

- **Fix 1 (Valkyrie)** requires a Valkyrie rebuild and pod restart. No other changes needed.
- **Fix 2 (ANDI)** requires an ANDI rebuild and pod restart. Run `resend_dataset_events/1`
  again after deploying to push corrected schema events to all downstream services.
- The two fixes are independent. Fix 1 resolves the immediate production failure. Fix 2
  prevents recurrence on the next Redis flush.
