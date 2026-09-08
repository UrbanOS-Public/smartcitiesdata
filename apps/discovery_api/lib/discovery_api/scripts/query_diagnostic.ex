defmodule DiscoveryApi.Scripts.QueryDiagnostic do
  @moduledoc """
  Diagnostic tool that walks the discovery-api query pipeline step-by-step,
  reporting exactly where a dataset fails to be queryable and why.

  Useful after Redis key evictions that cause Brook view-state loss.

  ## Usage (from an IEx session attached to the running discovery-api node)

      # By Trino system name (e.g. "org__datasetname")
      DiscoveryApi.Scripts.QueryDiagnostic.run("org__datasetname")

      # By dataset UUID
      DiscoveryApi.Scripts.QueryDiagnostic.run({:id, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"})

      # By URL path segments (org_name and dataset_name)
      DiscoveryApi.Scripts.QueryDiagnostic.run({:path, "my_org", "my_dataset"})

      # Scan ALL datasets and compare Redis vs ETS state
      DiscoveryApi.Scripts.QueryDiagnostic.scan_all()

  ## How Brook stores models in Redis

  The correct Redis key pattern is:

      discovery-api:view:state:models:<dataset_id>

  NOT "brook:discovery_api:view_state:models:*" — that prefix does not exist.
  See: deps/brook/lib/brook/storage/redis.ex line 181 for the key construction.
  """

  alias DiscoveryApi.Data.SystemNameCache
  alias DiscoveryApi.Schemas.Organizations

  @instance_name DiscoveryApi.instance_name()

  # Brook.Storage.Redis key format (deps/brook/lib/brook/storage/redis.ex:181):
  #   "#{namespace}:state:#{collection}:#{key}"
  # With namespace "discovery-api:view" (configured in runtime.exs):
  @brook_namespace "discovery-api:view"
  @model_key_prefix "#{@brook_namespace}:state:models"
  @test_query_template "SELECT MAX(FROM_UNIXTIME(_extraction_start_time)), COUNT(1) FROM ~s LIMIT 200"

  # ── ANSI helpers ──────────────────────────────────────────────────────────────

  defp green(text), do: "#{IO.ANSI.green()}#{text}#{IO.ANSI.reset()}"
  defp red(text), do: "#{IO.ANSI.red()}#{text}#{IO.ANSI.reset()}"
  defp yellow(text), do: "#{IO.ANSI.yellow()}#{text}#{IO.ANSI.reset()}"
  defp cyan(text), do: "#{IO.ANSI.cyan()}#{text}#{IO.ANSI.reset()}"
  defp bright(text), do: "#{IO.ANSI.bright()}#{text}#{IO.ANSI.reset()}"

  defp pass(msg), do: IO.puts("  #{green("✓")} #{msg}")
  defp fail(msg), do: IO.puts("  #{red("✗")} #{msg}")
  defp warn(msg), do: IO.puts("  #{yellow("⚠")} #{msg}")
  defp info(msg), do: IO.puts("  #{cyan("→")} #{msg}")

  defp header(msg) do
    IO.puts("\n#{bright(msg)}")
    IO.puts(String.duplicate("─", String.length(msg)))
  end

  defp recommend(lines) do
    IO.puts("\n#{bright(yellow("Recommendations:"))}")
    Enum.each(lines, fn line -> IO.puts("  #{yellow("•")} #{line}") end)
  end

  # ── Public API ────────────────────────────────────────────────────────────────

  @doc """
  Run the full diagnostic pipeline for one dataset.

  `input` can be:
  - `"org__system_name"` — Trino system name (string)
  - `{:id, "uuid"}` — dataset UUID
  - `{:path, "org_name", "dataset_name"}` — URL path segments
  """
  def run(input) do
    IO.puts("\n#{bright(cyan("=== Discovery API Query Diagnostic ==="))}\n")

    %{dataset_id: nil, system_name: nil, org_id: nil, failures: []}
    |> step_resolve_identity(input)
    |> step_check_redis_state()
    |> step_check_ets_state()
    |> step_check_organization()
    |> step_run_trino_query()
    |> print_summary()
  end

  @doc """
  Scan all datasets and compare Brook's Redis state vs in-memory ETS state.
  Identifies datasets that will become unqueryable after a pod restart (missing
  from Redis) and orphaned Redis keys (in Redis but not in ETS).
  """
  def scan_all do
    IO.puts("\n#{bright(cyan("=== Brook State Scan (all models) ==="))}\n")

    info("Scanning Redis key pattern: #{@model_key_prefix}:*")
    info("NOTE: 'brook:discovery_api:view_state:models:*' is WRONG — the correct prefix is above\n")

    redis_keys = Redix.command!(:redix, ["KEYS", "#{@model_key_prefix}:*"])
    redis_ids = MapSet.new(redis_keys, &extract_id_from_key/1)

    {:ok, ets_models} = Brook.ViewState.get_all(@instance_name, :models)
    ets_ids = MapSet.new(Map.keys(ets_models))

    IO.puts("Redis model keys:      #{bright(Integer.to_string(MapSet.size(redis_ids)))}")
    IO.puts("ETS (in-memory) models: #{bright(Integer.to_string(MapSet.size(ets_ids)))}")

    in_ets_not_redis = MapSet.difference(ets_ids, redis_ids)
    in_redis_not_ets = MapSet.difference(redis_ids, ets_ids)

    if MapSet.size(in_ets_not_redis) > 0 do
      IO.puts("\n#{bright(red("Models in ETS but MISSING from Redis (will break on pod restart):"))} #{MapSet.size(in_ets_not_redis)}")

      Enum.each(in_ets_not_redis, fn id ->
        model = Map.get(ets_models, id)
        IO.puts("  #{yellow(id)} — #{(model && model.systemName) || "?"}")
      end)

      recommend([
        "Run from the andi IEx console:",
        "  Andi.Scripts.ResendEvents.resend_dataset_events()",
        "This republishes dataset_update events from Postgres, rebuilding Redis state for ALL datasets.",
        "The 500ms delay between events prevents overwhelming Brook consumers."
      ])
    end

    if MapSet.size(in_redis_not_ets) > 0 do
      IO.puts("\n#{bright(yellow("In Redis but NOT in ETS (may be stale/orphaned keys):"))} #{MapSet.size(in_redis_not_ets)}")
      Enum.each(in_redis_not_ets, &IO.puts("  #{&1}"))
    end

    if MapSet.size(in_ets_not_redis) == 0 and MapSet.size(in_redis_not_ets) == 0 do
      IO.puts("\n#{green("✓ ETS and Redis are in sync (#{MapSet.size(ets_ids)} models).")}")
    end

    :ok
  end

  # ── Pipeline steps ────────────────────────────────────────────────────────────

  # Step 1a: resolve by {:path, org_name, dataset_name} → SystemNameCache lookup
  defp step_resolve_identity(state, {:path, org_name, dataset_name}) do
    header("[1/5] Resolve identity: path=#{org_name}/#{dataset_name}")

    case SystemNameCache.get(org_name, dataset_name) do
      nil ->
        fail("'#{org_name}/#{dataset_name}' not found in SystemNameCache (Cachex ETS)")
        warn("SystemNameCache is populated at startup from Brook ETS state.")
        warn("If Brook state was empty when discovery-api last started, this cache is also empty.")
        info("Try: DiscoveryApi.Scripts.QueryDiagnostic.run({:id, \"<uuid>\"})")
        info("  or: DiscoveryApi.Scripts.QueryDiagnostic.scan_all()")
        add_failure(state, :system_name_cache, "Not found in SystemNameCache")

      dataset_id ->
        pass("SystemNameCache hit → dataset_id: #{dataset_id}")
        %{state | dataset_id: dataset_id}
    end
  end

  # Step 1b: resolve by {:id, dataset_id} → direct Brook lookup
  defp step_resolve_identity(state, {:id, dataset_id}) do
    header("[1/5] Resolve identity: dataset_id=#{dataset_id}")

    case Brook.ViewState.get(@instance_name, :models, dataset_id) do
      {:ok, nil} ->
        fail("Dataset #{dataset_id} not found in Brook ETS state")
        warn("This dataset's model is missing from discovery-api's in-memory state.")
        add_failure(state, :system_name_cache, "Dataset ID not in Brook ETS state")

      {:ok, model} ->
        pass("Brook ETS has model: systemName=#{model.systemName}")
        %{state | dataset_id: dataset_id, system_name: model.systemName, org_id: get_in(model, [:organizationDetails, :id])}

      {:error, reason} ->
        fail("Brook.ViewState.get error: #{inspect(reason)}")
        add_failure(state, :system_name_cache, inspect(reason))
    end
  end

  # Step 1c: resolve by system_name string → scan Brook ETS
  defp step_resolve_identity(state, system_name) when is_binary(system_name) do
    header("[1/5] Resolve identity: system_name=#{system_name}")

    {:ok, all_models} = Brook.ViewState.get_all(@instance_name, :models)

    case Enum.find(all_models, fn {_id, m} -> m && m.systemName == system_name end) do
      nil ->
        fail("No model with systemName '#{system_name}' in Brook ETS")
        warn("Either the dataset was never processed by this instance, or its Brook state was lost.")
        redis_count = Redix.command!(:redix, ["KEYS", "#{@model_key_prefix}:*"]) |> length()
        info("Total Brook model keys in Redis right now: #{redis_count}")
        info("Run scan_all() for a full comparison of Redis vs ETS state.")
        add_failure(state, :system_name_cache, "system_name '#{system_name}' not in Brook ETS")

      {dataset_id, model} ->
        pass("Found in Brook ETS: id=#{dataset_id}")
        %{state | dataset_id: dataset_id, system_name: model.systemName, org_id: get_in(model, [:organizationDetails, :id])}
    end
  end

  # Skip remaining steps if identity resolution failed
  defp step_check_redis_state(%{failures: [{:system_name_cache, _} | _]} = state), do: state

  defp step_check_redis_state(%{dataset_id: dataset_id} = state) do
    header("[2/5] Brook Redis state")
    redis_key = "#{@model_key_prefix}:#{dataset_id}"
    info("Key: #{redis_key}")
    info("(Wrong pattern to avoid: 'brook:discovery_api:view_state:models:*' — that prefix does not exist)")

    case Redix.command(:redix, ["GET", redis_key]) do
      {:ok, nil} ->
        fail("Key MISSING from Redis: #{redis_key}")
        warn("If discovery-api restarts now, this dataset will not be loaded into ETS state.")

        event_key_pattern = "#{@brook_namespace}:events:models:#{dataset_id}:*"
        event_keys = Redix.command!(:redix, ["KEYS", event_key_pattern])

        cond do
          length(event_keys) > 0 ->
            warn("Found #{length(event_keys)} Brook event key(s) for this dataset — view state was evicted separately:")
            Enum.each(event_keys, fn k -> info(k) end)

          true ->
            warn("No Brook event keys found either. All state for this dataset is gone from Redis.")
        end

        add_failure(state, :redis_state, "Key missing: #{redis_key}")

      {:ok, _value} ->
        pass("Brook Redis key present")
        state

      {:error, reason} ->
        fail("Redis command failed: #{inspect(reason)}")
        add_failure(state, :redis_state, "Redis error: #{inspect(reason)}")
    end
  end

  defp step_check_ets_state(%{failures: [{:system_name_cache, _} | _]} = state), do: state

  defp step_check_ets_state(%{dataset_id: dataset_id} = state) do
    header("[3/5] Brook ETS (in-memory) state")

    case Brook.ViewState.get(@instance_name, :models, dataset_id) do
      {:ok, nil} ->
        fail("Dataset NOT in Brook ETS — discovery-api will return 404 for this dataset right now")
        add_failure(state, :ets_state, "Not in Brook ETS")

      {:ok, model} ->
        pass("In Brook ETS: systemName=#{model.systemName}, sourceType=#{model.sourceType}, private=#{model.private}")
        %{state | system_name: model.systemName, org_id: get_in(model, [:organizationDetails, :id])}

      {:error, reason} ->
        fail("Brook.ViewState.get error: #{inspect(reason)}")
        add_failure(state, :ets_state, inspect(reason))
    end
  end

  defp step_check_organization(%{failures: [{:system_name_cache, _} | _]} = state), do: state
  defp step_check_organization(%{failures: [{:ets_state, _} | _]} = state), do: state

  defp step_check_organization(%{org_id: nil} = state) do
    header("[4/5] Organization (Postgres)")
    warn("No org_id on model — cannot verify. This is unexpected.")
    state
  end

  defp step_check_organization(%{org_id: org_id} = state) do
    header("[4/5] Organization (Postgres) — org_id: #{org_id}")
    info("Organizations are stored in Postgres (not Brook). Checking DiscoveryApi.Repo...")

    case Organizations.get_organization(org_id) do
      {:ok, org} ->
        pass("Organization found in Postgres: name=#{org.name}")
        state

      {:error, reason} ->
        fail("Organization NOT found in Postgres: #{reason}")
        warn("dataset_update events require the org to exist in Postgres before a model can be stored.")
        warn("If org is missing, Andi.Scripts.ResendEvents.resend_dataset_events() will silently skip this dataset.")
        add_failure(state, :organization, reason)
    end
  end

  defp step_run_trino_query(%{system_name: nil} = state) do
    header("[5/5] Trino query — skipped (system_name not resolved)")
    state
  end

  defp step_run_trino_query(%{system_name: system_name} = state) do
    query = :io_lib.format(@test_query_template, [system_name]) |> IO.chardata_to_string()
    header("[5/5] Trino query")
    info("SQL: #{query}")

    session = DiscoveryApi.prestige_opts() |> Prestige.new_session()

    try do
      rows =
        session
        |> Prestige.query!(query)
        |> Prestige.Result.as_maps()

      pass("Trino query succeeded — #{length(rows)} row(s)")

      if rows != [] do
        info("Result: #{inspect(hd(rows))}")
      end

      state
    rescue
      error in Prestige.Error ->
        fail("Trino error: #{error.message}")
        add_failure(state, :trino, error.message)

      error in Prestige.ConnectionError ->
        fail("Trino connection error: #{inspect(error)}")
        add_failure(state, :trino, "Connection error")

      error ->
        fail("Unexpected error: #{inspect(error)}")
        add_failure(state, :trino, inspect(error))
    end
  end

  # ── Summary ───────────────────────────────────────────────────────────────────

  defp print_summary(%{failures: []} = state) do
    header("Summary")
    IO.puts(green("✓ All checks passed. This dataset should be queryable via discovery-api."))
    state
  end

  defp print_summary(%{failures: failures} = state) do
    header("Summary")
    IO.puts(red("✗ #{length(failures)} check(s) failed: #{failures |> Enum.map(&elem(&1, 0)) |> Enum.join(", ")}"))

    recs =
      failures
      |> Enum.flat_map(fn {step, _reason} -> recommendations_for(step) end)
      |> Enum.uniq()

    recommend(recs)
    state
  end

  defp recommendations_for(:system_name_cache) do
    [
      "Run scan_all() to see what's currently in Brook state.",
      "If Brook state is empty or incomplete, run from the andi IEx console:",
      "  Andi.Scripts.ResendEvents.resend_dataset_events()",
      "This sources from Postgres and works even after a full Redis flush."
    ]
  end

  defp recommendations_for(:redis_state) do
    [
      "The Brook Redis key is missing. After a pod restart this dataset won't be accessible.",
      "Run from andi IEx: Andi.Scripts.ResendEvents.resend_dataset_events()",
      "Check Redis maxmemory-policy — if set to allkeys-lru/lfu/random, Brook state keys",
      "  can be evicted. Consider setting 'maxmemory-policy noeviction' and managing",
      "  memory with explicit TTLs on application cache keys instead.",
      "Correct key to check: #{@model_key_prefix}:<dataset_id>"
    ]
  end

  defp recommendations_for(:ets_state) do
    [
      "Brook ETS is empty for this dataset — discovery-api is returning 404 right now.",
      "Run from andi IEx: Andi.Scripts.ResendEvents.resend_dataset_events()",
      "After events are published, discovery-api should process dataset_update within seconds.",
      "Confirm via: Brook.ViewState.get(:discovery_api, :models, \"<dataset_id>\")"
    ]
  end

  defp recommendations_for(:organization) do
    [
      "Organization missing from Postgres — dataset_update events will be silently discarded.",
      "Run FIRST from andi IEx: Andi.Scripts.ResendEvents.resend_user_org_assoc_events()",
      "Then: Andi.Scripts.ResendEvents.resend_dataset_events()",
      "Verify org exists: DiscoveryApi.Schemas.Organizations.get_organization(\"<org_id>\")"
    ]
  end

  defp recommendations_for(:trino) do
    [
      "Trino query failed even though Brook state exists — the Trino/Hive table may be missing.",
      "In Trino: SHOW TABLES IN hive.default LIKE '%<dataset_name>%'",
      "Verify forklift has successfully ingested data for this dataset.",
      "Check PRESTO_URL env var in the discovery-api pod."
    ]
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────

  defp add_failure(state, step, reason) do
    %{state | failures: state.failures ++ [{step, reason}]}
  end

  defp extract_id_from_key(key), do: key |> String.split(":") |> List.last()
end
