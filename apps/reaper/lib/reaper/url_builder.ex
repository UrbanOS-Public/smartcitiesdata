defmodule Reaper.UrlBuilder do
  alias Reaper.Collections.Extractions

  @moduledoc """
  This module builds a URL to download a source file
  """

  @doc """
  Returns a string containing the URL with all query string parameters based on the `Reaper.ReaperConfig`
  """
  @spec build(SmartCity.Dataset.t()) :: String.t()
  def build(%SmartCity.Dataset{technical: %{sourceUrl: url, sourceQueryParams: query_params}} = _dataset)
      when query_params == %{},
      do: build_url_path(url)

  def build(%SmartCity.Dataset{technical: %{sourceUrl: url, sourceQueryParams: query_params}} = dataset) do
    last_success_time = extract_last_success_time(dataset.id)

    string_params =
      query_params
      |> evaluate_parameters(last_success_time: last_success_time)
      |> URI.encode_query()

    "#{build_url_path(url)}?#{string_params}"
  end

  @spec decode_http_extract_step(%{assigns: any, context: %{queryParams: any, url: binary}}) ::
          binary
  def decode_http_extract_step(%{context: %{url: url, queryParams: query_params}, assigns: assigns})
      when query_params == %{} do
    build_safe_url_path(url, assigns)
  end

  def decode_http_extract_step(%{context: %{url: url, queryParams: query_params}, assigns: assigns}) do
      case url_has_query_params?(url) do
        true -> build_safe_url_path(url, assigns)
        false ->
          string_params =
            query_params
            |> safe_evaluate_parameters(assigns)
            |> URI.encode_query()

          "#{build_safe_url_path(url, assigns)}?#{string_params}"
      end
  end

  def build_safe_url_path(url, bindings) do
    regex = ~r"{{(.+?)}}"

    Regex.replace(regex, url, fn _match, var_name ->
      bindings[String.to_atom(var_name)]
    end)
  end

  defp build_url_path(url) do
    EEx.eval_string(url)
  end

  defp extract_last_success_time(dataset_id) do
    case Extractions.get_last_fetched_timestamp!(dataset_id) do
      nil -> false
      time -> time
    end
  end

  def safe_evaluate_parameters(parameters, bindings) do
    Enum.map(
      parameters,
      &safe_evaluate_parameter(&1, bindings)
    )
  end

  defp safe_evaluate_parameter({key, %{} = param_map}, bindings) do
    evaluated_map =
      Enum.map(param_map, fn param ->
        safe_evaluate_parameter(param, bindings)
      end)
      |> Enum.into(%{})

    {key, evaluated_map}
  end

  defp safe_evaluate_parameter({key, value}, bindings) do
    regex = ~r"{{(.+?)}}"

    value =
      Regex.replace(regex, to_string(value), fn _match, var_name ->
        bindings[String.to_atom(var_name)]
      end)

    {key, value}
  end

  defp evaluate_parameters(parameters, bindings) do
    Enum.map(
      parameters,
      &evaluate_parameter(&1, bindings)
    )
  end

  defp evaluate_parameter({key, value}, bindings) do
    {key, EEx.eval_string(value, bindings)}
  end

  defp url_has_query_params?(url), do: String.split(url, "?") |> Enum.count() > 1
end
