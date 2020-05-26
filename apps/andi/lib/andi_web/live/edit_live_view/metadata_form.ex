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
    ~L"""
    <div id="metadata-form" class="form-component">
      <div class="component-header" phx-click="toggle-component-visibility" phx-value-component="metadata_form">
        <h3 class="component-number component-number--<%= @visibility %>">1</h3>
        <h2 class="component-title component-title--<%= @visibility %> full-width">Enter Metadata</h2>
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
              <%= text_input(@technical, :sourceFormat, [class: "input--text input", readonly: true]) %>
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

            <div class="edit-button-group__messages">
              <%= if @save_success do %>
                <div id="success-message" class="metadata__success-message"><%= @success_message %></div>
              <% end %>
              <%= if @has_validation_errors do %>
                <div id="validation-error-message" class="metadata__error-message">There were errors with the dataset you tried to submit.</div>
              <% end %>
              <%= if @page_error do %>
                <div id="page-error-message" class="metadata__error-message">A page error occurred</div>
              <% end %>
            </div>

            <div class="edit-button-group__save-btn">
              <a href="#data-dictionary-form" id="next-button" class="btn btn--next btn--large btn--action">Next</a>
              <%= submit("Save", id: "save-button", name: "save-button", class: "btn btn--save btn--large", phx_value_action: "draft") %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} -> [key: description, value: actual_value] end)
  end

  defp rating_selection_prompt(), do: "Please Select a Value"

  defp get_language_options(), do: map_to_dropdown_options(Options.language())
  defp get_level_of_access_options, do: map_to_dropdown_options(Options.level_of_access())
  defp get_rating_options(), do: map_to_dropdown_options(Options.ratings())

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
