defmodule Andi.InputSchemas.FormTools do
  @moduledoc false
  alias Andi.InputSchemas.StructTools

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
    technical
    |> Map.update(:schema, [], fn schema ->
      schema
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {v, i}, acc ->
        Map.put(acc, to_string(i), v)
      end)
    end)
  end
end
