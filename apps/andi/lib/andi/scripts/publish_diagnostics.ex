defmodule Andi.Scripts.PublishDiagnostics do
  alias Andi.InputSchemas.Ingestion
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.InputConverter
  alias Andi.Services.IngestionStore
  alias Andi.Services.DatasetStore
  alias Ecto.Changeset

  # Runs the same validation the Publish button runs and prints every nested
  # error (schema fields, extract steps, transformations), not just the
  # top-level changeset.errors, which is frequently `[]` even when the
  # ingestion is invalid -- cast_assoc errors live on the child changesets
  # and never bubble up into the parent's flat :errors list.
  def diagnose_ingestion(ingestion_id) do
    case Ingestions.get(ingestion_id) do
      nil ->
        IO.puts("No ingestion found with id #{ingestion_id}")
        :not_found

      andi_ingestion ->
        changeset = andi_ingestion |> Ingestion.changeset(%{}) |> Ingestion.validate()

        IO.puts("Ingestion #{ingestion_id} (#{andi_ingestion.name})")
        IO.puts("  valid?: #{changeset.valid?}")

        errors = Changeset.traverse_errors(changeset, &render_error/1)
        print_errors(errors, changeset.valid?)

        check_top_level_selector(andi_ingestion)

        blanks = find_blank_ingestion_field_selectors(andi_ingestion)

        if blanks != [] do
          IO.puts("  #{length(blanks)} schema field(s) missing ingestion_field_selector:")
          Enum.each(blanks, fn f -> IO.puts("    - #{f.bread_crumb} (id=#{f.id})") end)
        end

        %{valid?: changeset.valid?, errors: errors, blank_selectors: blanks}
    end
  end

  # Runs the same validation the Publish Dataset button runs
  # (Dataset.changeset/2 + validate_unique_system_name/1).
  def diagnose_dataset(dataset_id) do
    case Datasets.get(dataset_id) do
      nil ->
        IO.puts("No dataset found with id #{dataset_id}")
        :not_found

      andi_dataset ->
        changeset = Datasets.full_validation_changeset_for_publish(%Dataset{}, StructTools.to_map(andi_dataset))

        IO.puts("Dataset #{dataset_id} (#{andi_dataset.business.dataTitle})")
        IO.puts("  valid?: #{changeset.valid?}")

        errors = Changeset.traverse_errors(changeset, &render_error/1)
        print_errors(errors, changeset.valid?)

        %{valid?: changeset.valid?, errors: errors}
    end
  end

  # Recursively finds schema fields (including nested subSchema) whose
  # ingestion_field_selector is blank. This field is required by the strict
  # publish validator (DataDictionary.changeset/3) but, for ingestion-scoped
  # schemas, ANDI's UI has no control to set it -- the "Ingestion Field" input
  # in data_dictionary_field_editor.ex only renders when editing a Dataset's
  # schema. Fields added any way other than the ingestion editor's own
  # "+ Add Field" button (bulk import, inferred-from-sample, etc.) can end up
  # blank silently, since it's not required to save a draft, only to publish.
  def find_blank_ingestion_field_selectors(ingestion_id) when is_binary(ingestion_id) do
    case Ingestions.get(ingestion_id) do
      nil -> []
      andi_ingestion -> find_blank_ingestion_field_selectors(andi_ingestion)
    end
  end

  def find_blank_ingestion_field_selectors(%Ingestion{schema: schema}) do
    schema
    |> List.wrap()
    |> Enum.flat_map(&walk_schema_field(&1, &1.name))
  end

  # Sets ingestion_field_selector to each blank field's own name -- mirroring
  # what the Dataset editor's "Sync Ingestion Field" checkbox does, since
  # that control isn't reachable for ingestion-scoped schemas. Defaults to a
  # dry run; pass dry_run: false to persist.
  def fix_blank_ingestion_field_selectors(ingestion_id, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, true)
    blanks = find_blank_ingestion_field_selectors(ingestion_id)

    if blanks == [] do
      IO.puts("Nothing to fix -- no blank ingestion_field_selector values found.")
    end

    Enum.map(blanks, fn %{id: id, name: name, bread_crumb: bread_crumb} ->
      if dry_run do
        IO.puts("[dry run] would set #{bread_crumb} (id=#{id}) ingestion_field_selector => #{inspect(name)}")
        {id, name, :skipped}
      else
        DataDictionary
        |> Andi.Repo.get!(id)
        |> Changeset.change(ingestion_field_selector: name)
        |> Andi.Repo.update!()

        IO.puts("set #{bread_crumb} (id=#{id}) ingestion_field_selector => #{inspect(name)}")
        {id, name, :updated}
      end
    end)
  end

  # Flags a topLevelSelector that parses as syntactically valid JSONPath but
  # is semantically a no-op -- e.g. the literal two characters `""` rather
  # than a truly empty/nil value. Jaxon.Path.parse/1 accepts it without
  # error, but Reaper.Decoder.Json will then match zero keys against it, so
  # extraction silently returns 0 records every cycle: no error anywhere in
  # the pipeline, just an END_OF_DATA sentinel on repeat.
  def check_top_level_selector(ingestion_id) when is_binary(ingestion_id) do
    case Ingestions.get(ingestion_id) do
      nil -> :not_found
      andi_ingestion -> check_top_level_selector(andi_ingestion)
    end
  end

  def check_top_level_selector(%Ingestion{topLevelSelector: selector, sourceFormat: source_format}) do
    cond do
      is_nil(selector) or selector == "" ->
        IO.puts("  topLevelSelector: nil/empty -- whole payload will be treated as one record. OK.")

      String.trim(selector) =~ ~r/^"+$/ ->
        IO.puts(
          "  WARNING topLevelSelector is #{inspect(selector)} -- looks like literal quote characters, " <>
            "not a real selector. This parses without error but matches zero keys."
        )

      source_format in ["json", "application/json"] ->
        case Jaxon.Path.parse(selector) do
          {:ok, _} -> IO.puts("  topLevelSelector #{inspect(selector)} parses OK (not verified against sample data).")
          {:error, err} -> IO.puts("  WARNING topLevelSelector #{inspect(selector)} fails to parse: #{inspect(err)}")
        end

      true ->
        IO.puts("  topLevelSelector: #{inspect(selector)}")
    end
  end

  # Resolves the open question from the f4822954 incident: does
  # ingestion_field_selector actually survive onto the wire schema that
  # Valkyrie reads, or is it always stripped before publish regardless of
  # what ANDI required at publish time? Compares three things side by side:
  #   1. the raw Postgres value (Ingestions.get/1) -- what Ingestion.validate/1
  #      actually checks at publish time, unaffected by wire conversion
  #   2. what today's conversion code would produce if republished right now
  #      (andi_ingestion_to_smrt_ingestion/1) -- this ALWAYS strips the field
  #      (drop_fields_from_dictionary_item/1 deletes it unconditionally), so
  #      it reads "MISSING" for every ingestion regardless of #1 and on its
  #      own proves nothing about Postgres health -- it's here to make that
  #      visible, not to be read in isolation
  #   3. what's actually sitting in Brook's view state from the last real
  #      publish (IngestionStore.get/1) -- the live artifact Reaper /
  #      Alchemist / Valkyrie / Forklift are actually consuming
  # #1 vs #3 disagreeing means the live pipeline is running on an event
  # published before Postgres went blank (or before ingestion_field_selector
  # existed at all) -- the pipeline is fine, but republishing today would
  # fail (if #1 is blank) or silently drop the field's real value onto the
  # floor (if #1 looks fine but the wire conversion still strips it).
  def check_wire_schema(ingestion_id) do
    IO.puts("Ingestion #{ingestion_id}")

    case Ingestions.get(ingestion_id) do
      nil ->
        IO.puts("  not found in ANDI's own store")

      andi_ingestion ->
        report_selector_presence("  Postgres, unstripped (Ingestions.get/1)", andi_ingestion.schema)

        case InputConverter.andi_ingestion_to_smrt_ingestion(andi_ingestion) do
          {:ok, %{schema: schema}} ->
            report_selector_presence("  would-publish-now (andi_ingestion_to_smrt_ingestion/1)", schema)

          {:error, reason} ->
            IO.puts("  could not convert to SmartCity.Ingestion: #{inspect(reason)}")
        end
    end

    case IngestionStore.get(ingestion_id) do
      {:ok, %{schema: schema}} when is_list(schema) ->
        report_selector_presence("  live Brook view (IngestionStore.get/1)", schema)

      {:ok, nil} ->
        IO.puts("  live Brook view: nothing published yet")

      other ->
        IO.puts("  live Brook view: unexpected result #{inspect(other)}")
    end
  end

  def check_wire_schema_for_dataset(dataset_id) do
    IO.puts("Dataset #{dataset_id}")

    case Datasets.get(dataset_id) do
      nil ->
        IO.puts("  not found in ANDI's own store")

      %{technical: %{schema: schema}} = andi_dataset ->
        report_selector_presence("  Postgres, unstripped (Datasets.get/1)", schema)

        case InputConverter.andi_dataset_to_smrt_dataset(andi_dataset) do
          {:ok, %{technical: %{schema: schema}}} ->
            report_selector_presence("  would-publish-now (andi_dataset_to_smrt_dataset/1)", schema)

          {:error, reason} ->
            IO.puts("  could not convert to SmartCity.Dataset: #{inspect(reason)}")
        end
    end

    case DatasetStore.get(dataset_id) do
      {:ok, %{technical: %{schema: schema}}} when is_list(schema) ->
        report_selector_presence("  live Brook view (DatasetStore.get/1)", schema)

      {:ok, nil} ->
        IO.puts("  live Brook view: nothing published yet")

      other ->
        IO.puts("  live Brook view: unexpected result #{inspect(other)}")
    end
  end

  defp report_selector_presence(label, schema) do
    fields = flatten_schema(schema)
    total = length(fields)
    missing = Enum.count(fields, &missing_selector?/1)

    cond do
      total == 0 -> IO.puts("#{label}: schema is empty")
      missing == 0 -> IO.puts("#{label}: ingestion_field_selector present on all #{total} field(s)")
      true -> IO.puts("#{label}: ingestion_field_selector MISSING/blank on #{missing}/#{total} field(s)")
    end
  end

  defp flatten_schema(schema) do
    schema
    |> List.wrap()
    |> Enum.flat_map(fn field ->
      [field | flatten_schema(get_any(field, :subSchema, "subSchema") || [])]
    end)
  end

  defp missing_selector?(field) do
    case get_any(field, :ingestion_field_selector, "ingestion_field_selector") do
      nil -> true
      "" -> true
      _ -> false
    end
  end

  # Wire-schema maps may come back atom-keyed (today's andi_*_to_smrt_*
  # helpers) or string-keyed (Brook view state populated from a raw decoded
  # event), depending on when/how they were written -- check both.
  defp get_any(map, atom_key, string_key) do
    cond do
      is_map(map) and Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
      is_map(map) and Map.has_key?(map, string_key) -> Map.get(map, string_key)
      true -> nil
    end
  end

  defp walk_schema_field(field, bread_crumb) do
    here =
      if blank?(field.ingestion_field_selector) do
        [%{id: field.id, name: field.name, bread_crumb: bread_crumb}]
      else
        []
      end

    children =
      field
      |> Map.get(:subSchema, [])
      |> List.wrap()
      |> Enum.flat_map(&walk_schema_field(&1, bread_crumb <> "." <> &1.name))

    here ++ children
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false

  defp print_errors(_errors, true), do: IO.puts("  No validation errors.")

  defp print_errors(errors, false) do
    IO.puts("  Nested validation errors:")
    IO.inspect(errors, pretty: true, label: "  errors")
  end

  defp render_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
