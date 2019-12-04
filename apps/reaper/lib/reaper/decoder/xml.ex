defmodule Reaper.Decoder.Xml do
  @moduledoc """
  Reaper.Decoder implementation to decode a csv file into a stream of records
  """

  defmodule XmlError do
    defexception [:message]
  end

  @behaviour Reaper.Decoder

  @impl Reaper.Decoder
  def decode(
        {:file, filename},
        %SmartCity.Dataset{technical: %{schema: schema, topLevelSelector: top_level_selector}} = dataset
      ) do
    try do
      stream =
        filename
        |> XMLStream.stream(top_level_selector)
        |> Stream.map(&Reaper.XmlSchemaMapper.map(&1, schema))

      {:ok, stream}
    rescue
      error ->
        {:error, "DatasetId: #{dataset.id}", error}
    end
  end

  @impl Reaper.Decoder
  def handle?(source_format) do
    String.downcase(source_format) == "text/xml"
  end
end
