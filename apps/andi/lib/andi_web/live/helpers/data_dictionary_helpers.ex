defmodule AndiWeb.Helpers.DataDictionaryHelpers do
  @moduledoc """
  This module contains dropdown options and text helpers shared between the submission and
  curator versions of the data dictionary field editor form.
  """
  import Phoenix.HTML.Form
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

      # |> Enum.reject(fn [key: _key, value: value] -> value == "list" end)

      _ ->
        []
    end
  end

  def is_source_format_xml(format) when format in ["xml", "text/xml"], do: true
  def is_source_format_xml(_), do: false

  def add_errors_to_form(:no_dictionary), do: :no_dictionary
  def add_errors_to_form(form), do: Map.put(form, :errors, form.source.errors)
end
