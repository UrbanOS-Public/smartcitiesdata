defmodule AndiWeb.Helpers.MetadataFormHelpers do
  @moduledoc """
  This module contains dropdown options and text helpers shared between the submission and
  curator versions of the metadata form.
  """
  alias AndiWeb.Views.Options
  alias Andi.Services.OrgStore
  alias Andi.Schemas.User
  alias Andi.InputSchemas.Organizations

  def map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} -> [key: description, value: actual_value] end)
  end

  def top_level_selector_label_class(source_format) when source_format in ["text/xml", "xml"], do: "label label--required"
  def top_level_selector_label_class(_), do: "label"

  def rating_selection_prompt(), do: "Please Select a Value"

  def get_language_options(), do: map_to_dropdown_options(Options.language())
  def get_level_of_access_options, do: map_to_dropdown_options(Options.level_of_access())
  def get_rating_options(), do: map_to_dropdown_options(Options.ratings())
  def get_source_type_options(), do: map_to_dropdown_options(Options.source_type())
  def get_org_options(), do: Options.organizations(Organizations.get_all())
  def get_owner_options(), do: Options.users(User.get_all())

  def get_source_format_options(source_type) when source_type in ["remote", "host"] do
    Options.source_format_extended()
  end

  def get_source_format_options(_), do: Options.source_format()

  def get_language(nil), do: "english"
  def get_language(lang), do: lang

  def get_license(nil), do: "https://creativecommons.org/licenses/by/4.0/"
  def get_license(license), do: license

  def keywords_to_string(nil), do: ""
  def keywords_to_string(keywords) when is_binary(keywords), do: keywords
  def keywords_to_string(keywords), do: Enum.join(keywords, ", ")
  def safe_calendar_value(nil), do: nil

  def safe_calendar_value(%{calendar: _, day: day, month: month, year: year}) do
    Timex.parse!("#{year}-#{month}-#{day}", "{YYYY}-{M}-{D}")
    |> NaiveDateTime.to_date()
  end

  def safe_calendar_value(value), do: value
end
