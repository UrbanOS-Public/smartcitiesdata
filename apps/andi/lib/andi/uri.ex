defmodule Andi.URI do
  @moduledoc """
  Andi's utility module for manipulating and formatting URIs with query parameters.
  """
  def merge_url_and_params(url, params) do
    {:ok, param_list_from_url} = extract_query_params(url)
    param_list_from_params = params_as_list_of_tuples(params)

    merged_params = merge_params(param_list_from_url, param_list_from_params)
    merged_url = update_url_with_params(url, merged_params)

    {merged_url, merged_params}
  end

  defp merge_params(params1, params2) do
    MapSet.new(params1 ++ params2)
    |> MapSet.to_list()
  end

  def update_url_with_params(nil, params), do: update_url_with_params("", params)

  def update_url_with_params(url, params) do
    query_params = Andi.URI.encode_query(params)
    uri = Andi.URI.parse(url)

    uri
    |> Map.put(:query, query_params)
    |> Andi.URI.to_string()
  end

  def clear_query_params(url), do: update_url_with_params(url, [])

  def extract_query_params(nil), do: extract_query_params("")

  def extract_query_params(url) do
    url
    |> Andi.URI.parse()
    |> Map.get(:query)
    |> Andi.URI.query_decoder()
  end

  def encode_query(params) do
    params
    |> params_as_list_of_tuples()
    |> URI.encode_query()
  end

  def params_as_list_of_tuples([%{} | _] = params), do: params_as_list_of_tuples(convert_key_value_to_tuple_list(params))
  def params_as_list_of_tuples(params) when is_map(params), do: params_as_list_of_tuples(convert_map_to_list(params))
  # conversion for map to list
  def params_as_list_of_tuples(params), do: params

  def to_string(%URI{query: ""} = uri) do
    URI.to_string(uri) |> String.trim_trailing("?")
  end

  def to_string(%URI{} = uri) do
    URI.to_string(uri)
  end

  def validate_uri(str) do
    uri = URI.parse(str)

    case uri do
      %URI{scheme: nil} -> {:error, uri}
      %URI{host: nil} -> {:error, uri}
      uri -> {:ok, uri}
    end
  end

  def query_decoder(nil), do: {:ok, []}

  def query_decoder(params) do
    list_of_kv_tuples =
      params
      |> URI.query_decoder()
      |> Enum.to_list()

    {:ok, list_of_kv_tuples}
  rescue
    _e in ArgumentError ->
      {:ignore, "partial encoding found"}
  end

  defdelegate parse(uri), to: URI

  defp convert_key_value_to_tuple_list(key_value_list) do
    key_value_list
    |> AtomicMap.convert(safe: false, underscore: false)
    |> Enum.map(fn param -> {param.key, param.value} end)
  end

  defp convert_map_to_list(list_in_map_form) do
    Enum.map(list_in_map_form, &convert_value_to_key_value/1)
  end

  defp convert_value_to_key_value({_k, v}) do
    {v["key"], v["value"]}
  end
end
