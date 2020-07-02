defmodule AndiWeb.EditLiveView.MetadataForm do
  @moduledoc """
    LiveComponent for editing dataset metadata
  """
  use Phoenix.LiveView

  import Phoenix.HTML.Form

  alias Andi.InputSchemas.Options
  alias Andi.InputSchemas.DisplayNames
  alias AndiWeb.ErrorHelpers
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.Form.Metadata
  alias Andi.InputSchemas.FormTools

  def mount(_, %{"dataset" => dataset}, socket) do
    new_metadata_changeset = Metadata.changeset_from_andi_dataset(dataset)
    dataset_exists =
      case Andi.Services.DatasetStore.get(dataset.id) do
        {:ok, nil} -> false
        _ -> true
      end

    {:ok, assign(socket,
        dataset_exists: dataset_exists,
        dataset_id: dataset.id,
        visibility: "expanded",
        changeset: new_metadata_changeset
      )}
  end

  def render(assigns) do
    action =
      case assigns.visibility do
        "collapsed" -> "EDIT"
        "expanded" -> "MINIMIZE"
      end

    valid =
      case assigns.changeset.valid? do
        true -> "valid"
        false -> "invalid"
      end

    ~L"""
    <div id="metadata-form" class="form-component">
      <div class="component-header" phx-click="toggle-component-visibility" phx-value-component="metadata_form">
        <div class="section-number">
          <h3 class="component-number component-number--<%= valid %>">1</h3>
          <div class="component-number-status--<%= valid %>"></div>
        </div>

        <div class="component-title full-width">
          <h2 class="component-title-text component-title-text--<%= @visibility %>">Enter Metadata</h2>
          <div class="component-title-action">
            <div class="component-title-action-text--<%= @visibility %>"><%= action %></div>
            <div class="component-title-icon--<%= @visibility %>"></div>
          </div>
        </div>
      </div>

      <div class="form-section">
      <%= f = form_for @changeset, "#", [phx_change: :cam, as: :form_data] %>
        <div class="component-edit-section--<%= @visibility %>">
          <div class="metadata-form-edit-section form-grid">
            <div class="metadata-form__title">
              <%= label(f, :dataTitle, DisplayNames.get(:dataTitle), class: "label label--required") %>
              <%= text_input(f, :dataTitle, class: "input", phx_value_field: "dataTitle", phx_blur: "validate_system_name") %>
              <%= ErrorHelpers.error_tag(@changeset, :dataTitle) %>
            </div>

            <div class="metadata-form__data-name">
              <%= label(f, :dataName, DisplayNames.get(:dataName), class: "label label--required") %>
              <%= text_input(f, :dataName, [class: "input input--text", readonly: true]) %>
              <%= ErrorHelpers.error_tag(@changeset, :dataName, bind_to_input: false) %>
            </div>

            <div class="metadata-form__description">
              <%= label(f, :description, DisplayNames.get(:description), class: "label label--required") %>
              <%= textarea(f, :description, class: "input textarea") %>
              <%= ErrorHelpers.error_tag(@changeset, :description) %>
            </div>

            <div class="metadata-form__maintainer-name">
              <%= label(f, :contactName, DisplayNames.get(:contactName), class: "label label--required") %>
              <%= text_input(f, :contactName, class: "input") %>
              <%= ErrorHelpers.error_tag(@changeset, :contactName) %>
            </div>

            <div class="metadata-form__maintainer-email">
              <%= label(f, :contactEmail, DisplayNames.get(:contactEmail), class: "label label--required") %>
              <%= text_input(f, :contactEmail, class: "input") %>
              <%= ErrorHelpers.error_tag(@changeset, :contactEmail) %>
            </div>

            <div class="metadata-form__release-date">
              <%= label(f, :issuedDate, DisplayNames.get(:issuedDate), class: "label label--required") %>
              <%= date_input(f, :issuedDate, class: "input", value: safe_calendar_value(input_value(f, :issuedDate))) %>
              <%= ErrorHelpers.error_tag(@changeset, :issuedDate, bind_to_input: false) %>
            </div>

            <div class="metadata-form__license">
              <%= label(f, :license, DisplayNames.get(:license), class: "label label--required") %>
              <%= text_input(f, :license, class: "input") %>
              <%= ErrorHelpers.error_tag(@changeset, :license) %>
            </div>

            <div class="metadata-form__top-level-selector">
              <%= label(f, :topLevelSelector, DisplayNames.get(:topLevelSelector), class: top_level_selector_label_class(input_value(f, :sourceFormat))) %>
              <%= text_input(f, :topLevelSelector, [class: "input--text input", readonly: input_value(f, :sourceFormat) not in ["xml", "json", "text/xml", "application/json"]]) %>
              <%= ErrorHelpers.error_tag(@changeset, :topLevelSelector) %>
            </div>

            <div class="metadata-form__update-frequency">
              <%= label(f, :publishFrequency, DisplayNames.get(:publishFrequency), class: "label label--required") %>
              <%= text_input(f, :publishFrequency, class: "input") %>
              <%= ErrorHelpers.error_tag(@changeset, :publishFrequency) %>
            </div>

            <div class="metadata-form__keywords">
              <%= label(f, :keywords, DisplayNames.get(:keywords), class: "label") %>
              <%= text_input(f, :keywords, value: keywords_to_string(input_value(f, :keywords)), class: "input") %>
              <div class="label label--inline">Separated by comma</div>
            </div>

            <div class="metadata-form__last-updated">
              <%= label(f, :modifiedDate, DisplayNames.get(:modifiedDate), class: "label") %>
              <%= date_input(f, :modifiedDate, class: "input", value: safe_calendar_value(input_value(f, :modifiedDate))) %>
            </div>

            <div class="metadata-form__spatial">
              <%= label(f, :spatial, DisplayNames.get(:spatial), class: "label") %>
              <%= text_input(f, :spatial, class: "input") %>
            </div>

            <div class="metadata-form__temporal">
              <%= label(f, :temporal, DisplayNames.get(:temporal), class: "label") %>
              <%= text_input(f, :temporal, class: "input") %>
              <%= ErrorHelpers.error_tag(@changeset, :temporal) %>
            </div>

            <div class="metadata-form__organization">
              <%= label(f, :orgTitle, DisplayNames.get(:orgTitle), class: "label label--required") %>
              <%= select(f, :orgId, get_org_options(), [class: "select", disabled: @dataset_exists, selected: ""]) %>
              <%= ErrorHelpers.error_tag(@changeset, :orgTitle) %>
            </div>

            <div class="metadata-form__language">
              <%= label(f, :language, DisplayNames.get(:language), class: "label") %>
              <%= select(f, :language, get_language_options(), value: get_language(input_value(f, :language)), class: "select") %>
            </div>

            <div class="metadata-form__homepage">
              <%= label(f, :homepage, DisplayNames.get(:homepage), class: "label") %>
              <%= text_input(f, :homepage, class: "input") %>
            </div>

            <div class="metadata-form__type">
              <%= label(f, :sourceType, DisplayNames.get(:sourceType), class: "label label--required") %>
              <%= select(f, :sourceType, get_source_type_options(), [class: "select", disabled: @dataset_exists]) %>
              <%= ErrorHelpers.error_tag(@changeset, :sourceType) %>
            </div>

            <div class="metadata-form__format">
              <%= label(f, :sourceFormat, DisplayNames.get(:sourceFormat), class: "label label--required") %>
              <%= select(f, :sourceFormat, get_source_format_options(input_value(f, :sourceType)), [class: "select", disabled: @dataset_exists]) %>
              <%= ErrorHelpers.error_tag(@changeset, :sourceFormat) %>
            </div>

            <div class="metadata-form__level-of-access">
              <%= label(f, :private, DisplayNames.get(:private), class: "label label--required") %>
              <%= select(f, :private, get_level_of_access_options(), class: "select") %>
              <%= ErrorHelpers.error_tag(@changeset, :private) %>
            </div>

            <div class="metadata-form__benefit-rating">
              <%= label(f, :benefitRating, DisplayNames.get(:benefitRating), class: "label label--required") %>
              <%= select(f, :benefitRating, get_rating_options(), class: "select", prompt: rating_selection_prompt()) %>
              <%= ErrorHelpers.error_tag(@changeset, :benefitRating, bind_to_input: false) %>
            </div>

            <div class="metadata-form__risk-rating">
              <%= label(f, :riskRating, DisplayNames.get(:riskRating), class: "label label--required") %>
              <%= select(f, :riskRating, get_rating_options(), class: "select", prompt: rating_selection_prompt()) %>
              <%= ErrorHelpers.error_tag(@changeset, :riskRating, bind_to_input: false) %>
            </div>
          </div>

          <div class="edit-button-group form-grid">
            <div class="edit-button-group__cancel-btn">
              <button type="button" class="btn btn--large" phx-click="cancel-edit">Cancel</button>
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

  def handle_event(
    "cam",
    %{"form_data" => form_data, "_target" => ["form_data", "business", "dataTitle" | _]},
    %{assigns: %{dataset_exists: false}} = socket
  ) do
    form_data
    |> FormTools.adjust_data_name()
    |> InputConverter.form_data_to_ui_changeset()
    |> complete_validation(socket)
  end

  defp complete_validation(changeset, socket) do
    new_changeset = Map.put(changeset, :action, :update)

    {:noreply, assign(socket, changeset: new_changeset)}
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
  defp get_source_type_options(), do: map_to_dropdown_options(Options.source_type())
  defp get_org_options(), do: Options.organizations()

  defp get_source_format_options(source_type) when source_type in ["remote", "host"] do
    Options.source_format_extended()
  end

  defp get_source_format_options(_), do: Options.source_format()

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
