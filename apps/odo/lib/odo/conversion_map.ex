defmodule Odo.ConversionMap do
  @moduledoc """
  Generates a map of information needed to correctly process
  the file conversion from one supported type to another,
  including the source and destination file types and paths,
  and the specific function to process the conversion.
  """

  use Properties, otp_app: :odo

  getter(:working_dir, generic: true)

  defstruct [:bucket, :original_key, :converted_key, :download_path, :converted_path, :conversion, :dataset_id]
  alias SmartCity.HostedFile

  def generate(%HostedFile{dataset_id: dataset_id, bucket: bucket, key: key}) do
    source_type = get_extension(key)
    conversion_map = get_conversion_map(source_type)

    case conversion_map do
      %{} ->
        {:ok,
         %Odo.ConversionMap{
           bucket: bucket,
           original_key: key,
           converted_key: String.replace_suffix(key, source_type, conversion_map["to"]),
           download_path: "#{working_dir()}/#{dataset_id}.#{conversion_map["from"]}",
           converted_path: "#{working_dir()}/#{dataset_id}.#{conversion_map["to"]}",
           conversion: conversion_map["function"],
           dataset_id: dataset_id
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_extension(file) do
    file
    |> String.split(".")
    |> List.last()
  end

  defp get_conversion_map(type) do
    case type do
      shapefile when shapefile in ["shapefile", "shp", "zip"] ->
        %{"from" => "shapefile", "to" => "geojson", "function" => &Geomancer.geo_json/1}

      _ ->
        {:error, "Unable to convert file; unsupported type"}
    end
  end
end
