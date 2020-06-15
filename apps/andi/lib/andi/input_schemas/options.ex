defmodule Andi.InputSchemas.Options do
  @moduledoc false

  def ratings() do
    %{
      0.0 => "Low",
      0.5 => "Medium",
      1.0 => "High"
    }
  end

  def language() do
    %{
      "english" => "English",
      "spanish" => "Spanish"
    }
  end

  def level_of_access() do
    %{
      "true" => "Private",
      "false" => "Public"
    }
  end

  def items() do
    %{
      "" => "",
      "string" => "String",
      "map" => "Map",
      "boolean" => "Boolean",
      "date" => "Date",
      "timestamp" => "Timestamp",
      "integer" => "Integer",
      "float" => "Float",
      "list" => "List",
      "json" => "JSON"
    }
  end

  def pii() do
    %{
      "" => "",
      "none" => "None",
      "direct" => "Direct",
      "indirect" => "Indirect"
    }
  end

  def demographic_traits() do
    %{
      "" => "",
      "none" => "None",
      "gender" => "Gender",
      "race" => "Race",
      "age" => "Age",
      "income" => "Income",
      "other" => "Other"
    }
  end

  def biased() do
    %{
      "" => "",
      "no" => "No",
      "yes" => "Yes"
    }
  end

  def masked() do
    %{
      "" => "",
      "n/a" => "N/A",
      "yes" => "Yes",
      "no" => "No"
    }
  end

  def source_format() do
    %{
      "" => "",
      "text/csv" => "CSV",
      "application/json" => "JSON",
      "text/xml" => "XML",
      "application/geo+json" => "GeoJSON",
      "application/gtfs+protobuf" => "GTFS Protobuf"
    }
  end

  def source_format_extended() do
    remote_host_formats = %{
      "application/octet-stream" => "Binary Data",
      "application/vnd.google-earth.kml+xml" => "KML",
      "application/zip" => "Zip Archive",
      "other" => "other"
    }

    Map.merge(source_format(), remote_host_formats)
  end

  def source_type() do
    %{
      "" => "",
      "ingest" => "Ingest",
      "stream" => "Stream",
      "host" => "Host",
      "remote" => "Remote"
    }
  end
end
