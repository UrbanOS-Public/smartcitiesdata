defmodule AndiWeb.Helpers.DataDictionaryHelpers do
  @moduledoc """
  This module contains dropdown options and text helpers shared between the submission and
  curator versions of the data dictionary field editor form.
  """
  import Phoenix.HTML.Form
  import SweetXml
  alias AndiWeb.Views.Options

  def get_item_types(), do: map_to_dropdown_options(Options.items())
  def get_item_types(field), do: map_to_dropdown_options(field, Options.items())
  def get_pii_types(), do: map_to_dropdown_options(Options.pii())
  def get_masked_types(), do: map_to_dropdown_options(Options.masked())
  def get_demographic_traits(), do: map_to_dropdown_options(Options.demographic_traits())
  def get_biased_types(), do: map_to_dropdown_options(Options.biased())

  def map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} -> [key: description, value: actual_value] end)
  end

  def map_to_dropdown_options(field, options) do
    case input_value(field, :type) do
      "list" ->
        options
        |> Enum.map(fn {actual_value, description} -> [key: description, value: actual_value] end)

      _ ->
        []
    end
  end

  def is_source_format_xml(format) when format in ["xml", "text/xml"], do: true
  def is_source_format_xml(_), do: false

  def add_errors_to_form(:no_dictionary), do: :no_dictionary
  def add_errors_to_form(form), do: Map.put(form, :errors, form.source.errors)

  def parse_csv(file_string) do
    file_string
    |> String.split("\n")
    |> Enum.take(2)
    |> List.update_at(0, &String.replace(&1, ~r/[^[:alnum:] _,]/, "", global: true))
    |> Enum.map(fn row -> String.split(row, ",") end)
    |> Enum.zip()
    |> Enum.map(fn {k, v} -> {k, convert_value(v)} end)
  end

  def parse_tsv(file_string) do
    file_string
    |> String.split("\n")
    |> Enum.take(2)
    |> List.update_at(0, &String.replace(&1, ~r/[^[:alnum:] _\t]/, "", global: true))
    |> Enum.map(fn row -> String.split(row, "\t") end)
    |> Enum.zip()
    |> Enum.map(fn {k, v} -> {k, convert_value(v)} end)
  end

  def parse_xml(file, top_level_selector \\ nil) do
    {:ok, parsed_file} = SAXMap.from_string(file)

    parsed_file_with_types =
      parsed_file
      |> parse_types()

    [parsed_file_with_types]
  end

  defp parse_types(map) when is_list(map) do
    Enum.map(map, fn submap -> parse_types(submap) end)
  end

  defp parse_types(map) do
    Enum.reduce(map, %{}, fn {key, val}, acc ->
      case val do
        val when is_map(val) -> Map.put_new(acc, key, parse_types(val))
        val when is_list(val) -> Map.put_new(acc, key, parse_types(val))
        val when is_binary(val) -> Map.put_new(acc, key, convert_value(val))
      end
    end)
  end

  defp convert_value(nil), do: nil

  defp convert_value(string) do
    case Jason.decode(string) do
      {:ok, value} -> value
      {:error, _} -> string
    end
  end
end
