defmodule Reaper.Decoder.GeoJson do
  @moduledoc """
  Decoder implementation that will decode GeoJSON
  """
  @behaviour Reaper.Decoder

  @impl Reaper.Decoder
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

  @impl Reaper.Decoder
  def handle?(source_format) when is_binary(source_format) do
    String.downcase(source_format) == "geojson"
  end

  @impl Reaper.Decoder
  def handle?(_source_format), do: false
end
