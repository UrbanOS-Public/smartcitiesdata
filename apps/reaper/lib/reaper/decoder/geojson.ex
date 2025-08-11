defmodule Reaper.Decoder.GeoJson do
  @moduledoc """
  Decoder implementation that will decode GeoJSON
  """
  @behaviour Reaper.Decoder

  alias Reaper.Decoder.Json

  @impl Reaper.Decoder
  def decode({:file, filename}, %{topLevelSelector: top_level_selector} = ingestion)
      when not is_nil(top_level_selector) do
    # Delegate to JSON decoder for path parsing, then extract GeoJSON features
    case Json.decode({:file, filename}, ingestion) do
      {:ok, data} ->
        case List.first(data) |> extract_geojson_features() do
          {:ok, features} -> {:ok, features}
          {:error, error} -> {:error, truncate_file_for_logging(filename), error}
        end
      {:error, file_content, error} ->
        {:error, file_content, error}
    end
  end

  def decode({:file, filename}, _ingestion) do
    data = File.read!(filename)

    with {:ok, json} <- Jason.decode(data),
         {:ok, mapped_features} <- extract_geojson_features(json) do
      {:ok, mapped_features}
    else
      {:error, error} ->
        {:error, truncate_file_for_logging(filename), error}
    end
  end

  defp extract_geojson_features(%{"features" => features} = input) when is_list(features) do
    {:ok, input |> List.wrap()}
  end

  defp extract_geojson_features(_data) do
    {:error, "Could not parse GeoJSON"}
  end

  @impl Reaper.Decoder
  def handle?(source_format) when is_binary(source_format) do
    String.downcase(source_format) == "application/geo+json"
  end

  @impl Reaper.Decoder
  def handle?(_source_format), do: false

  def truncate_file_for_logging(filename) do
    File.stream!(filename, [], 1000) |> Enum.at(0)
  end
end
