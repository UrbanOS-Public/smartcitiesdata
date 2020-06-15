defmodule Andi.InputSchemas.FormTools do
  @moduledoc false
  alias Andi.InputSchemas.StructTools
  alias Andi.Services.OrgStore

  def adjust_source_url_for_query_params(form_data) do
    source_url = form_data["technical"]["sourceUrl"]

    source_query_params =
      form_data
      |> Map.get("technical")
      |> Map.get("sourceQueryParams", %{})
      |> Enum.map(fn {_index, v} -> v end)

    updated_source_url = Andi.URI.update_url_with_params(source_url, source_query_params)

    put_in(form_data, ["technical", "sourceUrl"], updated_source_url)
  end

  def adjust_source_query_params_for_url(form_data_with_updated_url) do
    source_url = form_data_with_updated_url["technical"]["sourceUrl"]

    case Andi.URI.extract_query_params(source_url) do
      {:ok, params} ->
        form_data_params =
          params
          |> Enum.map(&convert_param_to_key_value/1)
          |> Enum.with_index()
          |> Enum.reduce(%{}, &convert_param_to_form_data/2)

        form_data_with_updated_url
        |> put_in(["technical", "sourceQueryParams"], form_data_params)

      _ ->
        form_data_with_updated_url
    end
  end

  def adjust_data_name(form_data) do
    data_title = form_data |> Map.get("business") |> Map.get("dataTitle")

    data_name =
      data_title
      |> String.replace(" ", "_", global: true)
      |> String.replace(~r/[^[:alnum:]_]/, "", global: true)
      |> String.downcase()

    org_name = get_in(form_data, ["technical", "orgName"])
    system_name = "#{org_name}__#{data_name}"

    form_data
    |> put_in(["technical", "dataName"], data_name)
    |> put_in(["technical", "systemName"], system_name)
  end

  def adjust_org_name(form_data) do
    org_id = form_data["business"]["orgTitle"]

    case OrgStore.get(org_id) do
      {:ok, org} ->
        org_name = org.orgName
        org_title = org.orgTitle
        org_id = org.id

        form_data
          |> put_in(["business", "orgTitle"], org_title)
          |> put_in(["technical", "orgName"], org_name)
          |> put_in(["technical", "orgId"], org_id)
      _ ->
        form_data
        |> put_in(["business", "orgTitle"], "")
        |> put_in(["technical", "orgName"], "")
    end
  end

  defp convert_param_to_form_data({value, index}, acc) do
    Map.put(acc, to_string(index), value)
  end

  defp convert_param_to_key_value({k, v}) do
    %{"key" => k, "value" => v}
  end

  def form_data_from_andi_dataset(dataset) do
    dataset
    |> StructTools.to_map()
    |> Map.update(:business, %{}, &convert_form_business/1)
    |> Map.update(:technical, %{}, &convert_form_technical/1)
  end

  defp convert_form_business(business) do
    business
    |> Map.update(:keywords, nil, &Enum.join(&1, ", "))
  end

  defp convert_form_technical(technical) do
    replace(technical, :schema, &convert_form_schema/1)
  end

  defp convert_form_schema(schema) do
    schema
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {v, i}, acc ->
      Map.put(
        acc,
        to_string(i),
        replace(v, :subSchema, &convert_form_schema/1)
      )
    end)
  end

  defp replace(map, key, function) do
    case Map.fetch(map, key) do
      {:ok, value} -> Map.put(map, key, function.(value))
      :error -> map
    end
  end
end
