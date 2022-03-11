defmodule Reaper.Decoder.Xml do
  @moduledoc """
  Reaper.Decoder implementation to decode a csv file into a stream of records
  """

  alias Reaper.XmlSchemaMapper

  defmodule XmlError do
    defexception [:message]
  end

  @behaviour Reaper.Decoder

  @impl Reaper.Decoder
  def decode(
        {:file, filename},
        %SmartCity.Ingestion{schema: schema, topLevelSelector: selector} = ingestion
      ) do
    try do
      stream =
        filename
        |> XMLStream.stream(selector)
        |> Stream.map(&XmlSchemaMapper.map(&1, schema))

      {:ok, stream}
    rescue
      error ->
        {:error, "IngestionId: #{ingestion.id}", error}
    end
  end

  @impl Reaper.Decoder
  def handle?(source_format) do
    String.downcase(source_format) == "text/xml"
  end
end
