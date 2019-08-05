defmodule Reaper.Decoder.GeoJson do
  @moduledoc """
  Decoder implementation that will decode GeoJSON
  """
  @behaviour Reaper.Decoder

  def decode({:file, filename}, _config) do
    data = File.read!(filename)

    case Jason.decode(data) do
      {:ok, json} ->
        extract_geojson_features(json, data)

      {:error, error} ->
        {:error, data, error}
    end
  end

  defp extract_geojson_features(%{"features" => features}, _data) when is_list(features) do
    {:ok, features}
  end

  defp extract_geojson_features(_json, data) do
    {:error, data, "Could not parse GeoJSON"}
  end
end
