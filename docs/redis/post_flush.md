# Redis Post-Flush Recovery

## Background

Brook (the event-sourcing library used by all Urbanos pipeline components) uses Redis as its
view-state store. Each component maintains a local `:datasets` (and, for some, `:ingestions`)
cache in Redis that is populated by handling `dataset_update` and `ingestion_update` events
as they flow through Kafka.

When Redis is flushed (`FLUSHALL` or `FLUSHDB`), every component loses that cache immediately.
Subsequent `data_extract_start` and `data_ingest_start` events then call `Brook.get!(..., :datasets, id)`
and receive `nil`, producing errors like:

```
[error] Could not find dataset_id: c62371cd-662a-43f5-b03f-94046c44acc8 in ingestion: ae7c993a-2fc3-4b69-9149-0dd14923f134
```

Affected components: **Valkyrie**, **Forklift** (and any other service whose event handler
reads from the Brook `:datasets` view state).

## Why Andi is the Recovery Point

Andi holds the canonical copy of all datasets and ingestions in its **PostgreSQL** database
(`Andi.Repo`). This database is unaffected by a Redis flush. The `Andi.Scripts.ResendEvents`
module reads from Postgres and re-broadcasts the appropriate events over Kafka/Brook, which
causes every downstream component to repopulate its Redis cache.

## Code Changes (branch: `otp23` / `master`)

File: `apps/andi/lib/andi/scripts/resend_events.ex`

### What changed

| Before | After |
|--------|-------|
| `resend_dataset_events/0` sourced datasets from `Andi.Services.DatasetStore` (Brook/Redis) — empty after a flush | Now sources from `Andi.InputSchemas.Datasets.get_all/0` (Postgres) and converts with `InputConverter.andi_dataset_to_smrt_dataset/1` |
| No ingestion resend | `resend_ingestion_events/0` added — reads from `Andi.InputSchemas.Ingestions.get_all/0` (Postgres), converts with `InputConverter.andi_ingestion_to_smrt_ingestion/1`, broadcasts `ingestion_update` events |
| No combined helper | `resend_all_events/0` added — calls both functions in order (datasets first, then ingestions) |

### Full contents of the file after the change

```elixir
defmodule Andi.Scripts.ResendEvents do
  alias Andi.Schemas.User
  alias SmartCity.UserOrganizationAssociate, as: UOA
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.InputConverter
  import SmartCity.Event

  def build_org_assocs_for_user(user) do
    user_orgs = user.organizations

    user_orgs |> Enum.map(fn org -> %UOA{org_id: org.id, subject_id: user.subject_id, email: user.email} end)
  end

  def resend_user_org_assoc_events() do
    users = User.get_all()

    users
    |> Enum.each(fn user ->
      build_org_assocs_for_user(user)
      |> Enum.each(fn assoc ->
        Brook.Event.send(:andi, user_organization_associate(), :data_migrator, assoc)
      end)
    end)
  end

  # Sources from Postgres so this works even after a Redis flush.
  def resend_dataset_events() do
    Datasets.get_all()
    |> Enum.each(fn andi_dataset ->
      case InputConverter.andi_dataset_to_smrt_dataset(andi_dataset) do
        {:ok, smrt_dataset} ->
          Brook.Event.send(:andi, dataset_update(), :data_migrator, smrt_dataset)

        {:error, reason} ->
          require Logger
          Logger.error("resend_dataset_events: failed to convert dataset #{andi_dataset.id}: #{inspect(reason)}")
      end
    end)
  end

  # Sources from Postgres so this works even after a Redis flush.
  def resend_ingestion_events() do
    Ingestions.get_all()
    |> Enum.each(fn andi_ingestion ->
      case InputConverter.andi_ingestion_to_smrt_ingestion(andi_ingestion) do
        {:ok, smrt_ingestion} ->
          Brook.Event.send(:andi, ingestion_update(), :data_migrator, smrt_ingestion)

        {:error, reason} ->
          require Logger
          Logger.error("resend_ingestion_events: failed to convert ingestion #{andi_ingestion.id}: #{inspect(reason)}")
      end
    end)
  end

  def resend_all_events() do
    resend_dataset_events()
    resend_ingestion_events()
  end
end
```

### Bug fixes (subsequent patch on `otp23` / `master`)

Two bugs were found when running `resend_dataset_events/0` and `resend_ingestion_events/0`
against a live database that contains draft/incomplete records:

#### 1. Draft datasets crash `SmartCity.Dataset.Business.new/1`

Newly-created datasets (e.g. `"New Dataset - 2025-11-25"`) have only a partial business record —
`contactName`, `description`, and `orgTitle` are nil. `StructTools.struct_to_map/1` strips nil
fields, so those keys are absent from the map. `SmartCity.Dataset.Business.new/1` pattern-matches
on all three and raises `ArgumentError: Invalid business metadata`.

**Fix:** `resend_dataset_events/0` now filters to `submission_status == :published` before
iterating, skipping all draft / submitted / rejected datasets.

File: `apps/andi/lib/andi/scripts/resend_events.ex`

```elixir
# before
Datasets.get_all()
|> Enum.each(...)

# after
Datasets.get_all()
|> Enum.filter(&(&1.submission_status == :published))
|> Enum.each(...)
```

#### 2. `transformations` not preloaded — crashes `SmartCity.Ingestion.new/1`

`Ingestions.get_all/0` only preloaded `extractSteps` and `schema`. The `transformations`
association was left as `%Ecto.Association.NotLoaded{}`, which `StructTools.struct_to_map/1`
silently drops. `SmartCity.Ingestion.new/1` requires the `transformations` key in its pattern
match, so the conversion raised `ArgumentError: Invalid ingestion metadata` for every ingestion,
including fully published ones.

**Fix:** `Ingestions.get_all/0` now calls `Repo.preload(:transformations)` after the query.
`resend_ingestion_events/0` also filters to `submissionStatus == :published` to skip drafts.

File: `apps/andi/lib/andi/input_schemas/ingestions.ex`

```elixir
# before
Repo.all(query)

# after
Repo.all(query)
|> Repo.preload(:transformations)
```

File: `apps/andi/lib/andi/scripts/resend_events.ex`

```elixir
# before
Ingestions.get_all()
|> Enum.each(...)

# after
Ingestions.get_all()
|> Enum.filter(&(&1.submissionStatus == :published))
|> Enum.each(...)
```

### Further bug fixes (second patch on `otp23` / `master`)

Six additional bugs surfaced during live recovery execution. All fixes are in the `otp23/master`
branch.

---

#### 3. `SmartCity.Ingestion.new/1` raises instead of returning `{:error, reason}`

`SmartCity.Dataset.new/1` wraps errors in `{:error, e}` via `rescue`. `SmartCity.Ingestion.new/1`
does not — it raises `ArgumentError` directly. The `case` statement in `resend_ingestion_events/0`
only matched `{:ok, ...}` and `{:error, ...}`, so any ingestion conversion failure bypassed error
logging and crashed the entire `Enum.each` loop.

**Fix:** `andi_ingestion_to_smrt_ingestion/1` now wraps the call in `rescue` and returns
`{:ok, result}` or `{:error, exception}`, matching the dataset converter's contract.

File: `apps/andi/lib/andi/input_schemas/input_converter.ex`

```elixir
# before
def andi_ingestion_to_smrt_ingestion(%Ingestion{} = ingestion) do
  ingestion
  |> StructTools.to_map()
  |> Map.put_new(:transformations, [])
  |> ...
  |> SmartCity.Ingestion.new()
end

# after
def andi_ingestion_to_smrt_ingestion(%Ingestion{} = ingestion) do
  result =
    ingestion
    |> StructTools.to_map()
    |> Map.put_new(:transformations, [])
    |> ...
    |> SmartCity.Ingestion.new()

  {:ok, result}
rescue
  e -> {:error, e}
end
```

---

#### 4. Andi-specific schema fields bloat the Kafka event payload

`drop_fields_from_dictionary_item/1` only stripped `:id`, `:dataset_id`, and `:bread_crumb` from
each schema field before building the SmartCity event. The fields `:technical_id`, `:ingestion_id`,
`:ingestion_field_selector`, and `:ingestion_field_sync` are Andi database foreign-key / UI
metadata that downstream services (Forklift, Valkyrie, Raptor) never use. Their presence
significantly increased Kafka message size for schemas with many fields, contributing to
Forklift Brook.Server processing timeouts.

**Fix:** Added four additional `Map.delete` calls in `drop_fields_from_dictionary_item/1`.

File: `apps/andi/lib/andi/input_schemas/input_converter.ex`

```elixir
# before
defp drop_fields_from_dictionary_item(schema) do
  schema
  |> Map.delete(:id)
  |> Map.delete(:dataset_id)
  |> Map.delete(:bread_crumb)
  |> Map.update(:subSchema, nil, &Enum.map(&1, fn s -> drop_fields_from_dictionary_item(s) end))
  |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  |> Map.new()
end

# after — also strips Andi-only FK/UI fields
defp drop_fields_from_dictionary_item(schema) do
  schema
  |> Map.delete(:id)
  |> Map.delete(:dataset_id)
  |> Map.delete(:bread_crumb)
  |> Map.delete(:technical_id)
  |> Map.delete(:ingestion_id)
  |> Map.delete(:ingestion_field_selector)
  |> Map.delete(:ingestion_field_sync)
  |> Map.update(:subSchema, nil, &Enum.map(&1, fn s -> drop_fields_from_dictionary_item(s) end))
  |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  |> Map.new()
end
```

---

#### 5. Burst of dataset events overwhelms Forklift Brook.Server

`resend_dataset_events/0` sent all dataset events as fast as possible. Forklift's
`dataset_update` handler calls `PrestigeHelper.table_exists?` and potentially
`DataWriter.init` (both synchronous Presto network calls) inside `Brook.Server.handle_call`.
The Brook GenServer call has a 5-second timeout. Under burst load, calls backed up in the
GenServer mailbox and timed out, crashing Forklift's Kafka consumer process.

**Fix:** `resend_dataset_events/1` now sleeps 500 ms between events (configurable via the
optional `delay_ms` argument). Pass `0` to skip the delay if downstream is confirmed healthy.

File: `apps/andi/lib/andi/scripts/resend_events.ex`

```elixir
# before
def resend_dataset_events() do
  Datasets.get_all()
  |> Enum.filter(&(&1.submission_status == :published))
  |> Enum.each(fn andi_dataset ->
    ...
    Brook.Event.send(...)
    ...
  end)
end

# after
def resend_dataset_events(delay_ms \\ 500) do
  Datasets.get_all()
  |> Enum.filter(&(&1.submission_status == :published))
  |> Enum.each(fn andi_dataset ->
    ...
    Brook.Event.send(...)
    Process.sleep(delay_ms)
    ...
  end)
end
```

The underlying Forklift issue (blocking Presto calls inside `Brook.Server.handle_call`) requires
a separate fix in Forklift — either making the Presto check asynchronous or increasing
`Brook.Config.event_processing_timeout`.

---

#### 6. Dataset `technical.schema` not preloaded — Forklift crashes writing data

`Datasets.get_all/0` only preloaded the `technical` and `business` associations. It did not
load the `DataDictionary` rows that back `Technical.schema`. `StructTools.struct_to_map/1`
silently dropped the `%Ecto.Association.NotLoaded{}` value, and `convert_andi_technical/1`'s
`Map.update(:schema, nil, ...)` fell back to the default `nil`.

Every dataset sent by `resend_dataset_events/0` therefore had `technical.schema: nil`. Forklift
stored these datasets in its Brook view state without error. The crash was deferred until the
first real data payload arrived and `Forklift.DataWriter.write_to_table/4` called
`add_ingestion_metadata_to_schema(nil)`, which performs `nil ++ [...]`, raising `ArgumentError`.

**Fix:** `Datasets.get_all/0` now preloads the nested schema in a single batched follow-up
query.

File: `apps/andi/lib/andi/input_schemas/datasets.ex`

```elixir
# before
Repo.all(query)

# after
Repo.all(query)
|> Repo.preload(technical: :schema)
```

---

#### 7. Extract steps processed in wrong order — secret value never injected

`Ingestions.get_all/0` returned extract steps in database insertion order, which is not
guaranteed to match `sequence`. In the affected ingestion the HTTP step (sequence 1) appeared
before the secret step (sequence 0) in the list. `InputConverter.andi_ingestion_to_smrt_ingestion/1`
did not sort before publishing the event, so Reaper stored the steps in reversed order in its
Brook view state.

`Reaper.DataExtract.ExtractStep.execute_extract_steps/2` iterated the list without sorting,
running the HTTP step first with empty `assigns`. When `Reaper.UrlBuilder.safe_evaluate_parameter/2`
tried to substitute `{{MD}}` from `assigns`, it received `nil` and crashed:
`iolist_to_binary([nil])` inside `Regex.replace/4`.

**Fix (two locations):**

1. `andi_ingestion_to_smrt_ingestion/1` sorts extract steps by `:sequence` before calling
   `SmartCity.Ingestion.new/1`, so the Kafka event and Reaper's view state always have steps
   in execution order.

   File: `apps/andi/lib/andi/input_schemas/input_converter.ex`

   ```elixir
   # before
   |> Map.update(:extractSteps, nil, &convert_andi_extract_steps/1)

   # after
   |> Map.update(:extractSteps, nil, fn steps ->
     steps
     |> convert_andi_extract_steps()
     |> Enum.sort_by(&Map.get(&1, :sequence, 0))
   end)
   ```

2. `execute_extract_steps/2` sorts defensively at runtime, guarding against any upstream source
   that delivers steps out of order. Handles both atom-keyed and string-keyed step maps.

   File: `apps/reaper/lib/reaper/data_extract/extract_step.ex`

   ```elixir
   # before
   def execute_extract_steps(ingestion, steps) do
     Enum.reduce(steps, %{}, fn step, acc ->
       step = AtomicMap.convert(step, underscore: false)
       execute_extract_step(ingestion, step, acc)
     end)
   end

   # after
   def execute_extract_steps(ingestion, steps) do
     steps
     |> Enum.sort_by(&(Map.get(&1, :sequence) || Map.get(&1, "sequence") || 0))
     |> Enum.reduce(%{}, fn step, acc ->
       step = AtomicMap.convert(step, underscore: false)
       execute_extract_step(ingestion, step, acc)
     end)
   end
   ```

Also removed a stray `IO.puts` debug statement that had been left in
`process_extract_step/2` for the `"secret"` step type.

---

## Code Changes (branch: `otp25_s3_enhancement`)

File: `apps/andi/lib/andi/scripts/resend_events.ex`

### What changed

| Before | After |
|--------|-------|
| `resend_dataset_events/0` sourced datasets from `Andi.Services.DatasetStore` (Brook/Redis) — empty after a flush | Now sources from `Andi.InputSchemas.Datasets.get_all/0` (Postgres) and converts with `InputConverter.andi_dataset_to_smrt_dataset/1` |
| No ingestion resend | `resend_ingestion_events/0` added — reads from `Andi.InputSchemas.Ingestions.get_all/0` (Postgres), converts with `InputConverter.andi_ingestion_to_smrt_ingestion/1`, broadcasts `ingestion_update` events |
| No combined helper | `resend_all_events/0` added — calls both functions in order (datasets first, then ingestions) |

Both new functions convert Andi Ecto structs to `SmartCity` structs before sending Brook events,
matching exactly what normal publish flows do.

### Full contents of the file after the change

This is the complete module — sufficient to apply the same fix to any branch:

```elixir
defmodule Andi.Scripts.ResendEvents do
  alias Andi.Schemas.User
  alias SmartCity.UserOrganizationAssociate, as: UOA
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.InputConverter
  import SmartCity.Event

  def build_org_assocs_for_user(user) do
    user_orgs = user.organizations

    user_orgs |> Enum.map(fn org -> %UOA{org_id: org.id, subject_id: user.subject_id, email: user.email} end)
  end

  def resend_user_org_assoc_events() do
    users = User.get_all()

    users
    |> Enum.each(fn user ->
      build_org_assocs_for_user(user)
      |> Enum.each(fn assoc ->
        Brook.Event.send(:andi, user_organization_associate(), :data_migrator, assoc)
      end)
    end)
  end

  # Sources from Postgres so this works even after a Redis flush.
  def resend_dataset_events() do
    Datasets.get_all()
    |> Enum.each(fn andi_dataset ->
      case InputConverter.andi_dataset_to_smrt_dataset(andi_dataset) do
        {:ok, smrt_dataset} ->
          Brook.Event.send(:andi, dataset_update(), :data_migrator, smrt_dataset)

        {:error, reason} ->
          require Logger
          Logger.error("resend_dataset_events: failed to convert dataset #{andi_dataset.id}: #{inspect(reason)}")
      end
    end)
  end

  # Sources from Postgres so this works even after a Redis flush.
  def resend_ingestion_events() do
    Ingestions.get_all()
    |> Enum.each(fn andi_ingestion ->
      case InputConverter.andi_ingestion_to_smrt_ingestion(andi_ingestion) do
        {:ok, smrt_ingestion} ->
          Brook.Event.send(:andi, ingestion_update(), :data_migrator, smrt_ingestion)

        {:error, reason} ->
          require Logger
          Logger.error("resend_ingestion_events: failed to convert ingestion #{andi_ingestion.id}: #{inspect(reason)}")
      end
    end)
  end

  def resend_all_events() do
    resend_dataset_events()
    resend_ingestion_events()
  end
end
```

### Key prerequisites to verify on the target branch

Before applying to another branch, confirm these modules exist with the same signatures:

| Module | Function | Returns |
|--------|----------|---------|
| `Andi.InputSchemas.Datasets` | `get_all/0` | list of Andi `%Dataset{}` Ecto structs |
| `Andi.InputSchemas.Ingestions` | `get_all/0` | list of Andi `%Ingestion{}` Ecto structs |
| `Andi.InputSchemas.InputConverter` | `andi_dataset_to_smrt_dataset/1` | `{:ok, %SmartCity.Dataset{}}` or `{:error, reason}` |
| `Andi.InputSchemas.InputConverter` | `andi_ingestion_to_smrt_ingestion/1` | `{:ok, %SmartCity.Ingestion{}}` or `{:error, reason}` |

If `InputConverter` does not exist on the older branch, look for equivalent conversion logic
in whichever module handles the publish flow (e.g. `EditLiveView` or a `DatasetPublisher` service)
and inline the conversion there.

### Bug fixes (subsequent patch on `otp25_s3_enhancement`)

Same two bugs as described under the `otp23/master` section above — apply the identical fixes:

1. **`apps/andi/lib/andi/input_schemas/ingestions.ex`** — add `|> Repo.preload(:transformations)` after `Repo.all(query)` in `get_all/0`.
2. **`apps/andi/lib/andi/scripts/resend_events.ex`** — add `|> Enum.filter(&(&1.submission_status == :published))` in `resend_dataset_events/0` and `|> Enum.filter(&(&1.submissionStatus == :published))` in `resend_ingestion_events/0`.

The full corrected `resend_events.ex` for this branch:

```elixir
defmodule Andi.Scripts.ResendEvents do
  alias Andi.Schemas.User
  alias SmartCity.UserOrganizationAssociate, as: UOA
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.InputConverter
  import SmartCity.Event

  def build_org_assocs_for_user(user) do
    user_orgs = user.organizations

    user_orgs |> Enum.map(fn org -> %UOA{org_id: org.id, subject_id: user.subject_id, email: user.email} end)
  end

  def resend_user_org_assoc_events() do
    users = User.get_all()

    users
    |> Enum.each(fn user ->
      build_org_assocs_for_user(user)
      |> Enum.each(fn assoc ->
        Brook.Event.send(:andi, user_organization_associate(), :data_migrator, assoc)
      end)
    end)
  end

  # Sources from Postgres so this works even after a Redis flush.
  def resend_dataset_events() do
    Datasets.get_all()
    |> Enum.filter(&(&1.submission_status == :published))
    |> Enum.each(fn andi_dataset ->
      case InputConverter.andi_dataset_to_smrt_dataset(andi_dataset) do
        {:ok, smrt_dataset} ->
          Brook.Event.send(:andi, dataset_update(), :data_migrator, smrt_dataset)

        {:error, reason} ->
          require Logger
          Logger.error("resend_dataset_events: failed to convert dataset #{andi_dataset.id}: #{inspect(reason)}")
      end
    end)
  end

  # Sources from Postgres so this works even after a Redis flush.
  def resend_ingestion_events() do
    Ingestions.get_all()
    |> Enum.filter(&(&1.submissionStatus == :published))
    |> Enum.each(fn andi_ingestion ->
      case InputConverter.andi_ingestion_to_smrt_ingestion(andi_ingestion) do
        {:ok, smrt_ingestion} ->
          Brook.Event.send(:andi, ingestion_update(), :data_migrator, smrt_ingestion)

        {:error, reason} ->
          require Logger
          Logger.error("resend_ingestion_events: failed to convert ingestion #{andi_ingestion.id}: #{inspect(reason)}")
      end
    end)
  end

  def resend_all_events() do
    resend_dataset_events()
    resend_ingestion_events()
  end
end
```

## Recovery Procedure

### 1. Identify the Andi pod

```bash
kubectl get pods -n mdot-ride-dev-ns | grep andi
```

Example output:
```
andi-7d9f6b8c4-xkp2v   1/1     Running   0   2d
```

### 2. Open an Elixir remote console on the Andi pod

```bash
kubectl exec -it <andi-pod-name> -n mdot-ride-dev-ns -- /app/bin/andi remote
```

Replace `<andi-pod-name>` with the pod name from step 1. You should see an `iex(andi@...)>` prompt.

> **Note:** The release binary is at `/app/bin/andi` inside the container. The `remote` subcommand
> connects to the already-running node without restarting it.

### 3. Run the recovery function

At the `iex` prompt:

```elixir
Andi.Scripts.ResendEvents.resend_all_events()
```

This broadcasts one `dataset_update` event and one `ingestion_update` event per record in Postgres.
All downstream components (Valkyrie, Forklift, etc.) handle these events and repopulate their
Brook view-state caches in Redis.

To resend only datasets or only ingestions:

```elixir
Andi.Scripts.ResendEvents.resend_dataset_events()
Andi.Scripts.ResendEvents.resend_ingestion_events()
```

### 4. Verify recovery

Watch for the error to stop appearing in downstream component logs:

```bash
kubectl logs -f deployment/valkyrie  -n mdot-ride-dev-ns | grep "Could not find dataset_id"
kubectl logs -f deployment/forklift  -n mdot-ride-dev-ns | grep "Could not find dataset_id"
```

If no new lines appear after the next extraction cycle the caches are healthy.

You can also confirm the Brook state was written back to Redis by checking key counts from any pod:

```bash
kubectl exec -it <andi-pod-name> -n mdot-ride-dev-ns -- /app/bin/andi remote
```

```elixir
{:ok, datasets}   = Andi.Services.DatasetStore.get_all()
{:ok, ingestions} = Andi.Services.IngestionStore.get_all()
length(datasets)
length(ingestions)
```

Both counts should match what is in the Andi UI.

## Clearing Stale Kafka Data After Recovery

After a Redis flush and resend recovery, the `validated-{dataset_id}` Kafka topics accumulate
a large backlog of stale messages — primarily `END_OF_DATA` markers and data rows from the
outage window. Forklift consumers replay these from their last committed offset on restart,
causing crash loops (nil schema, Trino queue pressure) even after the Brook view state has
been correctly restored.

The solution is to reset the Forklift consumer group offsets for all `validated-*` topics to
the latest position, causing Forklift to skip the stale backlog entirely and only process
new data from the point of recovery.

> **Prerequisites:** Forklift must be **scaled to zero** before resetting offsets. Kafka refuses
> to reset offsets for a consumer group that has active members.

### 1. Scale Forklift down

```bash
kubectl scale deployment forklift --replicas=0 -n mdot-ride-prod-ns
kubectl rollout status deployment/forklift -n mdot-ride-prod-ns
```

### 2. Find the Kafka pod and bootstrap address

```bash
kubectl get pods -n mdot-ride-prod-ns | grep kafka
# Use the broker/bootstrap service name — typically 'kafka:9092' or 'kafka-bootstrap:9092'
kubectl get svc -n mdot-ride-prod-ns | grep kafka
```

### 3. List all Forklift consumer groups

Forklift creates one consumer group per dataset, named after the validated topic:

```bash
kubectl exec -it <kafka-pod> -n mdot-ride-prod-ns -- \
  kafka-consumer-groups.sh --bootstrap-server kafka:9092 --list | grep "^validated-"
```

### 4. Reset all validated-* consumer groups to latest

This loop resets every Forklift consumer group to the end of its topic, skipping all
backlogged messages:

```bash
kubectl exec -it <kafka-pod> -n mdot-ride-prod-ns -- bash -c '
  BOOTSTRAP="kafka:9092"
  for group in $(kafka-consumer-groups.sh --bootstrap-server $BOOTSTRAP --list | grep "^validated-"); do
    echo "Resetting $group..."
    kafka-consumer-groups.sh --bootstrap-server $BOOTSTRAP \
      --group "$group" \
      --reset-offsets --to-latest \
      --all-topics \
      --execute
  done
  echo "Done."
'
```

To reset a single dataset's consumer group instead of all of them:

```bash
kubectl exec -it <kafka-pod> -n mdot-ride-prod-ns -- \
  kafka-consumer-groups.sh --bootstrap-server kafka:9092 \
    --group validated-<dataset-id> \
    --reset-offsets --to-latest \
    --topic validated-<dataset-id> \
    --execute
```

### 5. Verify the reset

Check that the consumer group lag is now 0 (or close to it):

```bash
kubectl exec -it <kafka-pod> -n mdot-ride-prod-ns -- \
  kafka-consumer-groups.sh --bootstrap-server kafka:9092 \
    --group validated-<dataset-id> \
    --describe
```

The `LAG` column should be 0 or a small number reflecting only messages produced since the reset.

### 6. Scale Forklift back up

```bash
kubectl scale deployment forklift --replicas=1 -n mdot-ride-prod-ns
```

Forklift will subscribe from the new (latest) offsets and process only fresh data, avoiding
the crash loops caused by replaying stale END_OF_DATA messages against a nil schema or an
overloaded Trino cluster.

### Notes

- **Brook event topics** (`event-stream`, `brook-*`) should **not** be reset. These carry
  `dataset_update` and `ingestion_update` events that Brook uses to rebuild view state. Resetting
  them would cause all components to lose their dataset/ingestion caches permanently.
- **Valkyrie** also has consumer groups for its input topics. If Valkyrie is similarly backlogged,
  the same approach applies — scale to zero, reset its consumer groups, scale back up. Valkyrie
  consumer groups are typically named after the raw ingestion input topics rather than
  `validated-*`.
- If using **Strimzi** as the Kafka operator, use `KafkaConsumerGroupReset` custom resources
  or the Strimzi operator's reset mechanism rather than `kafka-consumer-groups.sh` directly.

---

## Why Not Restart the Pods?

Restarting component pods does **not** help. Brook view state is populated only by handling
incoming events — a fresh pod starts with an empty cache and waits for new events. No new
`dataset_update`/`ingestion_update` events are published at startup, so the cache stays empty
until `resend_all_events/0` is called from Andi.
