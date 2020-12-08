defmodule Andi.InputSchemas.InputConverter do
  @moduledoc """
  Used to convert between SmartCity.Datasets, form data (defined by Andi.InputSchemas.DatasetInput), and Ecto.Changesets.
  """

  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Organization
  alias Andi.InputSchemas.StructTools
  alias AndiWeb.Helpers.FormTools

  def smrt_dataset_to_full_changeset(smrt_dataset) do
    smrt_dataset_to_full_changeset(%Dataset{}, smrt_dataset)
  end

  def smrt_dataset_to_full_changeset(nil, smrt_dataset) do
    smrt_dataset_to_full_changeset(%Dataset{}, smrt_dataset)
  end

  def smrt_dataset_to_full_changeset(%Dataset{} = andi_dataset, %{"id" => _} = smrt_dataset) do
    changes = atomize_dataset_map(smrt_dataset)

    smrt_dataset_to_full_changeset(andi_dataset, changes)
  end

  def smrt_dataset_to_full_changeset(%Dataset{} = andi_dataset, smrt_dataset) do
    changes = prepare_smrt_dataset_for_casting(smrt_dataset)

    Dataset.full_validation_changeset(andi_dataset, changes)
  end

  def smrt_dataset_to_changeset(smrt_dataset) do
    changes = prepare_smrt_dataset_for_casting(smrt_dataset)

    Dataset.changeset(%Dataset{}, changes)
  end

  def smrt_dataset_to_draft_changeset(smrt_dataset) do
    changes = prepare_smrt_dataset_for_casting(smrt_dataset)

    Dataset.changeset_for_draft(%Dataset{}, changes)
  end

  def prepare_smrt_dataset_for_casting(dataset) do
    dataset
    |> StructTools.to_map()
    |> AtomicMap.convert(safe: false, underscore: false)
    |> convert_smrt_business()
    |> convert_smrt_technical()
  end

  def form_data_to_ui_changeset(form_data \\ %{}) do
    form_data_as_params =
      form_data
      |> sort_form_data_schema_by_index()
      |> adjust_form_input()

    Dataset.changeset(%Dataset{}, form_data_as_params)
  end

  def form_data_to_changeset_draft(form_data \\ %{}) do
    form_data_as_params =
      form_data
      |> sort_form_data_schema_by_index()
      |> adjust_form_input()

    Dataset.changeset_for_draft(%Dataset{}, form_data_as_params)
  end

  def form_data_to_full_ui_changeset(form_data \\ %{}) do
    form_data_to_full_changeset(%Dataset{}, form_data)
  end

  def form_data_to_full_changeset(andi_dataset, form_data \\ %{}) do
    form_data_as_params = adjust_form_input(form_data)

    Dataset.full_validation_changeset(andi_dataset, form_data_as_params)
  end

  defp adjust_form_input(params) do
    params
    |> AtomicMap.convert(safe: false, underscore: false)
    |> convert_form_business()
    |> convert_form_technical()
  end

  def andi_dataset_to_full_ui_changeset(%Dataset{} = dataset) do
    dataset_as_map = StructTools.to_map(dataset)

    Dataset.full_validation_changeset(%Dataset{}, dataset_as_map)
  end

  def andi_dataset_to_full_ui_changeset_for_publish(%Dataset{} = dataset) do
    dataset_as_map = StructTools.to_map(dataset)

    Andi.InputSchemas.Datasets.full_validation_changeset_for_publish(%Dataset{}, dataset_as_map)
  end

  def andi_dataset_to_full_submission_changeset_for_publish(%Dataset{} = dataset) do
    dataset_as_map = StructTools.to_map(dataset)

    Andi.InputSchemas.Datasets.full_validation_submission_changeset_for_publish(%Dataset{}, dataset_as_map)
  end

  def andi_dataset_to_smrt_dataset(%Dataset{} = dataset) do
    dataset
    |> StructTools.to_map()
    |> convert_andi_business()
    |> convert_andi_technical()
    |> SmartCity.Dataset.new()
  end

  def andi_org_to_smrt_org(%Organization{} = org) do
    org
    |> StructTools.to_map()
    |> SmartCity.Organization.new()
  end

  def form_changes_from_changeset(%{errors: errors} = form_changeset) do
    error_fields = Keyword.keys(errors)

    form_changeset
    |> Ecto.Changeset.apply_changes()
    |> StructTools.to_map()
    |> add_error_fields_to_changes(error_fields)
  end

  def form_changes_from_changeset(placeholder_step_context), do: placeholder_step_context

  defp add_error_fields_to_changes(changes, error_fields) do
    Enum.reduce(error_fields, changes, fn error_field, acc ->
      Map.put_new(acc, error_field, nil)
    end)
  end

  defp convert_smrt_business(smrt_dataset) do
    smrt_dataset
    |> Map.update(:business, %{}, fn business ->
      business
      |> fix_modified_date()
    end)
  end

  defp convert_andi_business(andi_dataset) do
    andi_dataset
    |> Map.update!(:business, fn business ->
      business
      |> Map.update(:issuedDate, nil, &date_to_iso8601_datetime/1)
      |> Map.update(:modifiedDate, nil, &date_to_iso8601_datetime/1)
    end)
  end

  defp convert_form_business(form_dataset) do
    form_dataset
    |> Map.update(:business, %{}, fn business ->
      business
      |> fix_modified_date()
      |> Map.update(:keywords, nil, &keywords_to_list/1)
    end)
  end

  defp convert_smrt_technical(smrt_dataset) do
    smrt_dataset
    |> Map.update(:technical, %{}, fn technical ->
      technical
      |> Map.update(:sourceHeaders, [], &to_key_value_list/1)
      |> Map.update(:sourceQueryParams, [], &to_key_value_list/1)
      |> convert_source_url()
      |> Map.update(:sourceQueryParams, [], &to_key_value_list/1)
      |> Map.update(:extractSteps, [], &convert_smrt_extract_steps/1)
      |> FormTools.replace(:schema, fn schema ->
        Enum.map(schema, &add_dataset_id(&1, smrt_dataset.id))
      end)
    end)
  end

  defp convert_smrt_extract_steps(nil), do: []

  defp convert_smrt_extract_steps(extract_steps) do
    Enum.map(extract_steps, fn step ->
      Map.update(step, :context, %{}, fn context ->
        update_context_from_smrt_step(context, step.type)
      end)
    end)
  end

  defp update_context_from_smrt_step(context, "http") do
    context
    |> encode_extract_step_body_as_json()
    |> Map.update(:queryParams, [], &to_key_value_list/1)
    |> Map.update(:headers, [], &to_key_value_list/1)
  end

  defp update_context_from_smrt_step(context, "auth") do
    context
    |> encode_extract_step_body_as_json()
    |> Map.update(:headers, [], &to_key_value_list/1)
  end

  defp update_context_from_smrt_step(context, _), do: context

  defp encode_extract_step_body_as_json(%{body: body} = smrt_extract_step) when body != nil do
    Map.put(smrt_extract_step, :body, Jason.encode!(body))
  end

  defp encode_extract_step_body_as_json(smrt_extract_step), do: smrt_extract_step

  defp add_dataset_id(schema, dataset_id, parent_bread_crumb \\ "") do
    bread_crumb = parent_bread_crumb <> schema.name

    schema
    |> Map.put(:dataset_id, dataset_id)
    |> Map.put(:bread_crumb, bread_crumb)
    |> FormTools.replace(:subSchema, fn sub_schema ->
      Enum.map(sub_schema, &add_dataset_id(&1, dataset_id, bread_crumb <> " > "))
    end)
  end

  defp convert_andi_technical(andi_dataset) do
    andi_dataset
    |> Map.update!(:technical, fn technical ->
      technical
      |> Map.update(:sourceUrl, nil, &Andi.URI.clear_query_params/1)
      |> Map.update(:sourceQueryParams, nil, &convert_key_value_to_map/1)
      |> Map.update(:sourceHeaders, nil, &convert_key_value_to_map/1)
      |> Map.update(:extractSteps, nil, &convert_andi_extract_steps/1)
      |> Map.update(:schema, nil, fn schema ->
        Enum.map(schema, &drop_fields_from_dictionary_item/1)
      end)
    end)
  end

  defp convert_andi_extract_steps(andi_extract_steps) do
    andi_extract_steps
    |> Enum.map(fn step ->
      step
      |> Map.delete(:id)
      |> Map.delete(:technical_id)
      |> Map.update(:context, nil, fn context -> update_context_from_andi_step(context, step.type) end)
      |> Map.put(:assigns, %{})
    end)
  end

  defp update_context_from_andi_step(context, "http") do
    context
    |> decode_andi_extract_step_body()
    |> Map.put_new(:body, %{})
    |> Map.put_new(:protocol, nil)
    |> Map.update(:queryParams, nil, &convert_key_value_to_map/1)
    |> Map.update(:headers, nil, &convert_key_value_to_map/1)
  end

  defp update_context_from_andi_step(context, "date") do
    context
    |> Map.put_new(:deltaTimeValue, nil)
    |> Map.update(:deltaTimeUnit, nil, &ensure_nil_unit/1)
  end

  defp update_context_from_andi_step(context, "auth") do
    context
    |> decode_andi_extract_step_body()
    |> Map.put_new(:body, %{})
    |> Map.put_new(:encodeMethod, "json")
    |> Map.update(:headers, nil, &convert_key_value_to_map/1)
  end

  defp update_context_from_andi_step(context, _type), do: context

  defp ensure_nil_unit(""), do: nil
  defp ensure_nil_unit(unit), do: unit

  defp decode_andi_extract_step_body(%{body: body} = http_extract_step) when body not in ["", nil] do
    Map.put(http_extract_step, :body, Jason.decode!(body))
  end

  defp decode_andi_extract_step_body(andi_extract_step), do: andi_extract_step

  defp drop_fields_from_dictionary_item(schema) do
    schema
    |> Map.delete(:id)
    |> Map.delete(:dataset_id)
    |> Map.delete(:bread_crumb)
    |> Map.update(:subSchema, nil, fn sub_schema ->
      Enum.map(sub_schema, &drop_fields_from_dictionary_item/1)
    end)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp convert_form_technical(form_dataset) do
    form_dataset
    |> Map.update(:technical, %{}, fn technical ->
      technical
      |> Map.put_new(:sourceQueryParams, %{})
      |> Map.put_new(:sourceHeaders, %{})
      |> FormTools.replace(:schema, &convert_form_schema(&1, form_dataset[:id]))
    end)
  end

  defp convert_form_schema(schema, form_data_id, parent_bread_crumb \\ "") do
    schema
    |> Enum.map(fn {_index, schema_field} ->
      add_dataset_id_to_form(schema_field, form_data_id, parent_bread_crumb)
    end)
  end

  defp add_dataset_id_to_form(schema, dataset_id, parent_bread_crumb) do
    bread_crumb = parent_bread_crumb <> schema.name

    schema
    |> Map.put(:dataset_id, dataset_id)
    |> Map.put(:bread_crumb, bread_crumb)
    |> FormTools.replace(:subSchema, &convert_form_schema(&1, dataset_id, bread_crumb <> " > "))
  end

  defp atomize_dataset_map(dataset) when is_map(dataset) do
    dataset
    |> atomize_top_level()
    |> Map.update(:business, nil, &atomize_top_level/1)
    |> Map.update(:technical, nil, &atomize_top_level/1)
    |> update_in([:technical, :schema], fn schema -> Enum.map(schema, &atomize_top_level/1) end)
  end

  defp atomize_top_level(map) do
    Map.new(map, fn {key, val} -> {SmartCity.Helpers.safe_string_to_atom(key), val} end)
  end

  def keywords_to_list(nil), do: []
  def keywords_to_list(""), do: []

  def keywords_to_list(keywords) when is_binary(keywords) do
    keywords
    |> String.split(", ")
    |> Enum.map(&String.trim/1)
  end

  def keywords_to_list(keywords) when is_list(keywords), do: keywords

  defp date_to_iso8601_datetime(nil), do: nil

  defp date_to_iso8601_datetime(date) do
    time_const = "00:00:00Z"

    "#{Date.to_iso8601(date)}T#{time_const}"
  end

  defp convert_key_value_to_map(key_value) do
    Enum.reduce(key_value, %{}, fn entry, acc -> Map.put(acc, entry.key, entry.value) end)
  end

  defp convert_source_url(map) do
    source_url = Map.get(map, :sourceUrl)
    source_query_params = Map.get(map, :sourceQueryParams)

    {url, params} = Andi.URI.merge_url_and_params(source_url, source_query_params)

    Map.put(map, :sourceUrl, url)
    |> Map.put(:sourceQueryParams, params)
  end

  defp to_key_value_list(field_as_map) do
    Enum.map(field_as_map, &to_key_value/1)
  end

  defp to_key_value({k, v}) do
    %{key: to_string(k), value: v}
  end

  defp sort_form_data_schema_by_index(form_data) do
    form_data
    |> Map.update("technical", %{}, fn technical ->
      FormTools.replace(technical, "schema", &sort_map_by_numerical_keys/1)
    end)
  end

  defp sort_map_by_numerical_keys(map) do
    Enum.sort_by(map, fn {k, _v} ->
      Integer.parse(k)
    end)
  end

  def fix_modified_date(map) do
    map
    |> Map.get_and_update(:modifiedDate, fn
      %{calendar: "Elixir.Calendar.ISO", day: day, month: month, year: year} ->
        date =
          Timex.parse!("#{year}-#{month}-#{day}", "{YYYY}-{M}-{D}")
          |> NaiveDateTime.to_date()

        {date, date}

      "" ->
        {"", nil}

      current_value ->
        {current_value, current_value}
    end)
    |> elem(1)
  end
end
