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

  defp build_url_path(url) do
    EEx.eval_string(url)
  end

  defp extract_last_success_time(dataset_id) do
    case Extractions.get_last_fetched_timestamp!(dataset_id) do
      nil -> false
      time -> time
    end
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
end
