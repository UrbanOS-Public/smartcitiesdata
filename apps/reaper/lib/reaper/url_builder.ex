defmodule Reaper.UrlBuilder do
  alias Reaper.Sickle
  @moduledoc false
  def build(%Sickle{sourceUrl: url, queryParams: query_params} = dataset)
      when query_params == %{},
      do: url

  def build(%Sickle{sourceUrl: url, queryParams: query_params} = dataset) do
    last_success_time = extract_last_success_time(dataset)

    string_params =
      query_params
      |> evaluate_parameters(last_success_time: last_success_time)
      |> URI.encode_query()

    "#{url}?#{string_params}"
  end

  defp extract_last_success_time(dataset) do
    case dataset.lastSuccessTime do
      nil -> false
      time -> convert_timestamp(dataset.lastSuccessTime)
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
