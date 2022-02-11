defmodule Reaper.Decoder.Json do
  @moduledoc """
  Decoder implementation that will decode the file as JSON
  """
  @behaviour Reaper.Decoder

  @impl Reaper.Decoder

  def decode({:file, filename}, %{topLevelSelector: top_level_selector} = _ingestion)
      when not is_nil(top_level_selector) do
    with {:ok, query} <- Jaxon.Path.parse(top_level_selector),
         {:ok, data} <- json_file_query(filename, query) do
      decoded = List.wrap(data)
      {:ok, decoded}
    else
      {:error, error} ->
        {:error, truncate_file_for_logging(filename), error}
    end
  end

  def decode({:file, filename}, _ingestion) do
    data = File.read!(filename)
    
    case Jason.decode(data) do
      {:ok, response} ->
        {:ok, List.wrap(response)}

      {:error, error} ->
        {:error, truncate_file_for_logging(filename), error}
    end
  end

  @impl Reaper.Decoder
  def handle?(source_format) when is_binary(source_format) do
    String.downcase(source_format) == "application/json"
  end

  def handle?(_source_format), do: false

  def json_file_query(filename, query) do
    data =
      filename
      |> File.stream!()
      |> Jaxon.Stream.query(query)
      |> Enum.to_list()
      |> List.flatten()

    {:ok, data}
  rescue
    error ->
      parse_json_file_query_errors(error)
  end

  def truncate_file_for_logging(filename) do
    File.stream!(filename, [], 1000) |> Enum.at(0)
  end

  defp parse_json_file_query_errors(error) do
    case error do
      %Jaxon.ParseError{unexpected: :end_array} -> {:ok, []}
      _ -> {:error, error}
    end
  end
end
