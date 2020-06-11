defmodule AndiWeb.EditLiveView.MetadataForm do
  @moduledoc """
    LiveComponent for editing dataset metadata
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  alias Phoenix.HTML.Link
  alias Andi.InputSchemas.Options
  alias Andi.InputSchemas.DisplayNames
  alias AndiWeb.ErrorHelpers

  def mount(socket) do
    {:ok, socket}
  end

  def render(assigns) do
    action =
      case assigns.visibility do
        "collapsed" -> "EDIT"
        "expanded" -> "MINIMIZE"
      end

    ~L"""
    <div id="metadata-form" class="form-component">
      <div class="component-header" phx-click="toggle-component-visibility" phx-value-component="metadata_form">
        <h3 class="component-number component-number--<%= @visibility %>">1</h3>

        <div class="component-title full-width">
          <h2 class="component-title-text component-title-text--<%= @visibility %>">Enter Metadata</h2>
          <div class="component-title-action">
            <div class="component-title-action-text--<%= @visibility %>"><%= action %></div>
            <div class="component-title-icon--<%= @visibility %>"></div>
          </div>
        </div>
      </div>

      <div class="form-section">
        <div class="component-edit-section--<%= @visibility %>">
          <div class="metadata-form-edit-section form-grid">
            <div class="metadata-form__title">
              <%= label(@business, :dataTitle, DisplayNames.get(:dataTitle), class: "label label--required") %>
              <%= text_input(@business, :dataTitle, class: "input") %>
              <%= ErrorHelpers.error_tag(@business, :dataTitle) %>
            </div>

            <div class="metadata-form__description">
              <%= label(@business, :description, DisplayNames.get(:description), class: "label label--required") %>
              <%= textarea(@business, :description, class: "input textarea") %>
              <%= ErrorHelpers.error_tag(@business, :description) %>
            </div>

            <div class="metadata-form__maintainer-name">
              <%= label(@business, :contactName, DisplayNames.get(:contactName), class: "label label--required") %>
              <%= text_input(@business, :contactName, class: "input") %>
              <%= ErrorHelpers.error_tag(@business, :contactName) %>
            </div>

            <div class="metadata-form__maintainer-email">
              <%= label(@business, :contactEmail, DisplayNames.get(:contactEmail), class: "label label--required") %>
              <%= text_input(@business, :contactEmail, class: "input") %>
              <%= ErrorHelpers.error_tag(@business, :contactEmail) %>
            </div>

            <div class="metadata-form__release-date">
              <%= label(@business, :issuedDate, DisplayNames.get(:issuedDate), class: "label label--required") %>
              <%= date_input(@business, :issuedDate, class: "input", value: safe_calendar_value(input_value(@business, :issuedDate))) %>
              <%= ErrorHelpers.error_tag(@business, :issuedDate, bind_to_input: false) %>
            </div>

            <div class="metadata-form__license">
              <%= label(@business, :license, DisplayNames.get(:license), class: "label label--required") %>
              <%= text_input(@business, :license, class: "input") %>
              <%= ErrorHelpers.error_tag(@business, :license) %>
            </div>

            <div class="metadata-form__top-level-selector">
              <%= label(@technical, :topLevelSelector, DisplayNames.get(:topLevelSelector), class: top_level_selector_label_class(input_value(@technical, :sourceFormat))) %>
              <%= text_input(@technical, :topLevelSelector, [class: "input--text input", readonly: input_value(@technical, :sourceFormat) not in ["xml", "json", "text/xml", "application/json"]]) %>
              <%= ErrorHelpers.error_tag(@technical, :topLevelSelector) %>
            </div>

            <div class="metadata-form__update-frequency">
              <%= label(@business, :publishFrequency, DisplayNames.get(:publishFrequency), class: "label label--required") %>
              <%= text_input(@business, :publishFrequency, class: "input") %>
              <%= ErrorHelpers.error_tag(@business, :publishFrequency) %>
            </div>

            <div class="metadata-form__keywords">
              <%= label(@business, :keywords, DisplayNames.get(:keywords), class: "label") %>
              <%= text_input(@business, :keywords, value: keywords_to_string(input_value(@business, :keywords)), class: "input") %>
              <div class="label label--inline">Separated by comma</div>
            </div>

            <div class="metadata-form__last-updated">
              <%= label(@business, :modifiedDate, DisplayNames.get(:modifiedDate), class: "label") %>
              <%= date_input(@business, :modifiedDate, class: "input", value: safe_calendar_value(input_value(@business, :modifiedDate))) %>
            </div>

            <div class="metadata-form__spatial">
              <%= label(@business, :spatial, DisplayNames.get(:spatial), class: "label") %>
              <%= text_input(@business, :spatial, class: "input") %>
            </div>

            <div class="metadata-form__temporal">
              <%= label(@business, :temporal, DisplayNames.get(:temporal), class: "label") %>
              <%= text_input(@business, :temporal, class: "input") %>
              <%= ErrorHelpers.error_tag(@business, :temporal) %>
            </div>

            <div class="metadata-form__organization">
              <%= label(@business, :orgTitle, DisplayNames.get(:orgTitle), class: "label label--required") %>
              <%= text_input(@business, :orgTitle, [class: "input input--text", readonly: true]) %>
              <%= ErrorHelpers.error_tag(@business, :orgTitle) %>
            </div>

            <div class="metadata-form__language">
              <%= label(@business, :language, DisplayNames.get(:language), class: "label") %>
              <%= select(@business, :language, get_language_options(), value: get_language(input_value(@business, :language)), class: "select") %>
            </div>

            <div class="metadata-form__homepage">
              <%= label(@business, :homepage, DisplayNames.get(:homepage), class: "label") %>
              <%= text_input(@business, :homepage, class: "input") %>
            </div>

            <div class="metadata-form__format">
              <%= label(@technical, :sourceFormat, DisplayNames.get(:sourceFormat), class: "label label--required") %>
              <%= select(@technical, :sourceFormat, get_source_format_options(), [class: "select", disabled: @dataset_exists]) %>
              <%= ErrorHelpers.error_tag(@technical, :sourceFormat) %>
            </div>

            <div class="metadata-form__level-of-access">
              <%= label(@technical, :private, DisplayNames.get(:private), class: "label label--required") %>
              <%= select(@technical, :private, get_level_of_access_options(), class: "select") %>
              <%= ErrorHelpers.error_tag(@technical, :private) %>
            </div>

            <div class="metadata-form__benefit-rating">
              <%= label(@business, :benefitRating, DisplayNames.get(:benefitRating), class: "label label--required") %>
              <%= select(@business, :benefitRating, get_rating_options(), class: "select", prompt: rating_selection_prompt()) %>
              <%= ErrorHelpers.error_tag(@business, :benefitRating, bind_to_input: false) %>
            </div>

            <div class="metadata-form__risk-rating">
              <%= label(@business, :riskRating, DisplayNames.get(:riskRating), class: "label label--required") %>
              <%= select(@business, :riskRating, get_rating_options(), class: "select", prompt: rating_selection_prompt()) %>
              <%= ErrorHelpers.error_tag(@business, :riskRating, bind_to_input: false) %>
            </div>
          </div>

          <div class="edit-button-group form-grid">
            <div class="edit-button-group__cancel-btn">
              <%= Link.button("Cancel", to: "/", method: "get", class: "btn btn--large") %>
            </div>

            <div class="edit-button-group__save-btn">
              <a href="#data-dictionary-form" id="next-button" class="btn btn--next btn--large btn--action" phx-click="toggle-component-visibility" phx-value-component-collapse="metadata_form" phx-value-component-expand="data_dictionary_form">Next</a>
              <%= submit("Save Draft", id: "save-button", name: "save-button", class: "btn btn--save btn--large", phx_value_action: "draft") %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp top_level_selector_label_class(source_format) when source_format in ["text/xml", "xml"], do: "label label--required"
  defp top_level_selector_label_class(_), do: "label"

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} -> [key: description, value: actual_value] end)
  end

  defp rating_selection_prompt(), do: "Please Select a Value"

  defp get_language_options(), do: map_to_dropdown_options(Options.language())
  defp get_level_of_access_options, do: map_to_dropdown_options(Options.level_of_access())
  defp get_rating_options(), do: map_to_dropdown_options(Options.ratings())
  defp get_source_format_options(), do: map_to_dropdown_options(Options.source_format())

  defp get_language(nil), do: "english"
  defp get_language(lang), do: lang

  defp keywords_to_string(nil), do: ""
  defp keywords_to_string(keywords) when is_binary(keywords), do: keywords
  defp keywords_to_string(keywords), do: Enum.join(keywords, ", ")

  defp safe_calendar_value(nil), do: nil

  defp safe_calendar_value(%{calendar: _, day: day, month: month, year: year}) do
    Timex.parse!("#{year}-#{month}-#{day}", "{YYYY}-{M}-{D}")
    |> NaiveDateTime.to_date()
  end

  defp safe_calendar_value(value), do: value
end
