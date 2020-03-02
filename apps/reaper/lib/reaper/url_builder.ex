defmodule Reaper.UrlBuilder do
  alias Reaper.Collections.Extractions

  @moduledoc """
  This module builds a URL to download a source file
  """

  @doc """
  Returns a string containing the URL with all query string parameters based on the `Reaper.ReaperConfig`
  """
  @spec build(SmartCity.Dataset.t()) :: String.t()
  def build(%SmartCity.Dataset{technical: %{sourceUrl: "s3://" <> _location = url}} = _dataset), do: url

  def build(%SmartCity.Dataset{technical: %{sourceUrl: url, sourceQueryParams: query_params}, version: version} = _dataset)
      when query_params == %{} and version in ["0.1", "0.2", "0.3", "0.4"],
      do: build_url_path(url)

  def build(%SmartCity.Dataset{technical: %{sourceUrl: url, sourceQueryParams: query_params}, version: version} = dataset) and version in ["0.5", "0.6", "0.7"] do
    last_success_time = extract_last_success_time(dataset.id)

    VersionHelper.versioned_call([VersionRange("0.1", "0.4") => {UrlBuilderV1, :build, []}])

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

  [
    %KeyValuePair{
      key: "stuff"
      value: "1"
    },
    %KeyValuePair{
      key: "stuff"
      value: "2"
    }
  ]

  %SmartCity.Dataset.Technical{
    sourceQueryParams: %{
      "key[]" => ["3", "2"]
    }
  }

  defp evaluate_parameter({key, value}, bindings) when is_list(value) do
    {key, Enum.map(value, &EEx.eval_string(&1, bindings))}
  end

  defp evaluate_parameter({key, value}, bindings) do
    {key, EEx.eval_string(value, bindings)}
  end
end
