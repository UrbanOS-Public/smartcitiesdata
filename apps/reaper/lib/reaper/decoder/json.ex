defmodule Reaper.Decoder.Json do
  @moduledoc """
  Decoder implementation that will decode the file as JSON
  """
  @behaviour Reaper.Decoder

  @impl Reaper.Decoder

  def decode({:file, filename}, %{topLevelSelector: top_level_selector} = _ingestion)
      when not is_nil(top_level_selector) do
    with {:ok, query} <- parse_json_path(top_level_selector),
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
      |> File.read!()
      |> Jaxon.Stream.from_binary()
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

  defp parse_json_path(json_path) do
    try do
      query = convert_json_path_to_jaxon_query(json_path)
      {:ok, query}
    rescue
      _error ->
        # Create a Jaxon.ParseError - let's create it properly
        {:error, create_parse_error("Invalid JSONPath: #{json_path}")}
    end
  end

  defp convert_json_path_to_jaxon_query(json_path) do
    # Convert JSONPath expressions like "$.data", "$.data[*]", "$.[*].data"
    # to Jaxon.Stream query format [:root, "data", :all]
    
    # Handle special case for root array access like "$.[*].property"
    if String.starts_with?(json_path, "$.[*]") do
      # Remove "$.[*]." and process the rest
      remaining_path = String.replace_leading(json_path, "$.[*].", "")
      segments = if remaining_path == "", do: [], else: String.split(remaining_path, ".")
      query_parts = 
        segments
        |> Enum.map(&convert_segment/1)
        |> List.flatten()
      [:root, :all | query_parts]
    else
      # Remove the leading "$." 
      path = String.replace_leading(json_path, "$.", "")
      
      # Split by dots to get path segments
      segments = String.split(path, ".")
      
      # Convert each segment to appropriate Jaxon query format and flatten
      query_parts = 
        segments
        |> Enum.map(&convert_segment/1)
        |> List.flatten()
      
      # Add :root at the beginning for Jaxon.Stream
      [:root | query_parts]
    end
  end

  defp convert_segment(segment) do
    cond do
      # Handle array access like "data[*]" -> ["data", :all]
      String.contains?(segment, "[*]") ->
        base = String.replace(segment, "[*]", "")
        [base, :all]
      
      # Handle invalid array access like "data[XX]" - this should cause an error
      String.contains?(segment, "[") && !String.contains?(segment, "[*]") ->
        raise "Invalid array selector in JSONPath"
      
      # Regular object property
      true ->
        [segment]
    end
  end

  defp create_parse_error(message) do
    # Create a struct that resembles Jaxon.ParseError for test compatibility
    %{
      __struct__: Jaxon.ParseError,
      unexpected: :invalid_json_path,
      data: message
    }
  end
end
