defmodule Reaper.UrlBuilder do
  alias Reaper.ReaperConfig

  @moduledoc """
  This module builds a URL to download a source file
  """

  @doc """
  Returns a string containing the URL with all query string parameters based on the `Reaper.ReaperConfig`
  """
  @spec build(ReaperConfig.t()) :: String.t()
  def build(%ReaperConfig{sourceUrl: url, sourceQueryParams: query_params} = _reaper_config)
      when query_params == %{},
      do: url

  def build(%ReaperConfig{sourceUrl: url, sourceQueryParams: query_params} = reaper_config) do
    last_success_time = extract_last_success_time(reaper_config)

    string_params =
      query_params
      |> evaluate_parameters(last_success_time: last_success_time)
      |> URI.encode_query()

    "#{url}?#{string_params}"
  end

  defp extract_last_success_time(reaper_config) do
    case reaper_config.lastSuccessTime do
      nil -> false
      _time -> convert_timestamp(reaper_config.lastSuccessTime)
    end
  end

  defp convert_timestamp(timestamp) do
    {:ok, dt, _} = DateTime.from_iso8601(timestamp)
    dt
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
