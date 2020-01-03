defmodule Reaper.Decoder.Json do
  @moduledoc """
  Decoder implementation that will decode the file as JSON
  """
  @behaviour Reaper.Decoder

  @impl Reaper.Decoder

  def decode({:file, filename}, %{technical: %{topLevelSelector: top_level_selector}} = _dataset)
      when not is_nil(top_level_selector) do
    with {:ok, query} <- Jaxon.Path.parse(top_level_selector),
         {:ok, data} <- json_file_query(filename, query) do
      {:ok, data}
    else
      {:error, error} ->
        {:error, File.read!(filename), error}
    end
  end

  def decode({:file, filename}, _dataset) do
    data = File.read!(filename)

    case Jason.decode(data) do
      {:ok, response} ->
        {:ok, List.wrap(response)}

      {:error, error} ->
        {:error, data, error}
    end
  end

  @impl Reaper.Decoder
  def handle?(source_format) when is_binary(source_format) do
    String.downcase(source_format) == "application/json"
  end

  def handle?(_source_format), do: false

  defp json_file_query(filename, query) do
    data =
      filename
      |> File.stream!()
      |> Jaxon.Stream.query(query)
      |> Enum.to_list()
      |> List.flatten()
      |> List.wrap()

    {:ok, data}
  rescue
    error -> {:error, error}
  end
end
