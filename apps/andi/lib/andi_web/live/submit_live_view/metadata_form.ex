defmodule AndiWeb.SubmitLiveView.MetadataForm do
  @moduledoc """
    LiveComponent for public submissions of dataset metadata
  """
  use Phoenix.LiveView
  use AndiWeb.FormSection, schema_module: AndiWeb.InputSchemas.MetadataFormSchema
  import Phoenix.HTML.Form
  import Phoenix.HTML.Link

  alias AndiWeb.Views.Options
  alias AndiWeb.Views.DisplayNames
  alias AndiWeb.ErrorHelpers
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.Services.OrgStore
  alias AndiWeb.InputSchemas.MetadataFormSchema
  alias AndiWeb.Helpers.FormTools

  def mount(_, %{"dataset" => dataset}, socket) do
    new_metadata_changeset = MetadataFormSchema.changeset_from_andi_dataset(dataset)

    dataset_exists =
      case Andi.Services.DatasetStore.get(dataset.id) do
        {:ok, nil} -> false
        _ -> true
      end

    AndiWeb.Endpoint.subscribe("toggle-visibility")
    AndiWeb.Endpoint.subscribe("form-save")
    AndiWeb.Endpoint.subscribe("source-format")

    {:ok,
     assign(socket,
       dataset_exists: dataset_exists,
       dataset_id: dataset.id,
       visibility: "expanded",
       validation_status: "expanded",
       changeset: new_metadata_changeset
     )}
  end

  #  TODO: Keep the required fields "Title, Name, Description, Format, Name, and Email"
  #  Keep the optional fields "Last updated, Spatial and Temporal boundaries, Keywords, Homepage URL, and Language"

  def render(assigns) do
    action =
      case assigns.visibility do
        "collapsed" -> "EDIT"
        "expanded" -> "MINIMIZE"
      end

    ~L"""
    <div id="metadata-form" class="form-component">
      <div class="component-header" phx-click="toggle-component-visibility">
        <div class="section-number">
          <h3 class="component-number component-number--<%= @validation_status %> component-number--<%= @visibility %>">1</h3>
          <div class="component-number-status--<%= @validation_status %>"></div>
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
        <%= f = form_for @changeset, "#", [phx_change: :validate, phx_submit: :save, as: :form_data] %>
        <%= hidden_input(f, :dataName) %> <!-- TODO: Will this work? -->

          <div class="component-edit-section--<%= @visibility %>">
            <div class="submission-metadata-form-edit-section form-grid">
              <div class="metadata-form__title">
                <%= label(f, :dataTitle, DisplayNames.get(:dataTitle), class: "label label--required") %>
                <%= text_input(f, :dataTitle, class: "input", phx_value_field: "dataTitle", phx_blur: "validate_system_name", phx_debounce: "1000") %>
                <%= ErrorHelpers.error_tag(f, :dataTitle, bind_to_input: false) %>
              </div>

              <!--<div class="metadata-form__data-name">
                <%= label(f, :dataName, DisplayNames.get(:dataName), class: "label label--required") %>
                <%= text_input(f, :dataName, [class: "input input--text", readonly: true]) %>
                <%= ErrorHelpers.error_tag(f, :dataName, bind_to_input: false) %>
              </div>-->

              <div class="metadata-form__description">
                <%= label(f, :description, DisplayNames.get(:description), class: "label label--required") %>
                <%= textarea(f, :description, class: "input textarea") %>
                <%= ErrorHelpers.error_tag(f, :description, bind_to_input: false) %>
              </div>

              <div class="metadata-form__maintainer-name">
                <%= label(f, :contactName, DisplayNames.get(:contactName), class: "label label--required") %>
                <%= text_input(f, :contactName, class: "input") %>
                <%= ErrorHelpers.error_tag(f, :contactName, bind_to_input: false) %>
              </div>

              <div class="metadata-form__maintainer-email">
                <%= label(f, :contactEmail, DisplayNames.get(:contactEmail), class: "label label--required") %>
                <%= text_input(f, :contactEmail, class: "input") %>
                <%= ErrorHelpers.error_tag(f, :contactEmail, bind_to_input: false) %>
              </div>

              <div class="metadata-form__release-date">
                <%= label(f, :issuedDate, DisplayNames.get(:issuedDate), class: "label label--required") %>
                <%= date_input(f, :issuedDate, class: "input", value: safe_calendar_value(input_value(f, :issuedDate))) %>
                <%= ErrorHelpers.error_tag(f, :issuedDate, bind_to_input: false) %>
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
                <div class="help-text-label">
                  <%= label(f, :spatial, DisplayNames.get(:spatial), class: "label") %>
                  <a href="https://resources.data.gov/resources/dcat-us/#spatial" target="_blank">Formatting Help</a>
                </div>
                <%= text_input(f, :spatial, class: "input") %>
              </div>

              <div class="metadata-form__temporal">
                <div class="help-text-label">
                  <%= label(f, :temporal, DisplayNames.get(:temporal), class: "label") %>
                  <a href="https://resources.data.gov/resources/dcat-us/#temporal" target="_blank">Formatting Help</a>
                </div>
                <%= text_input(f, :temporal, class: "input") %>
                <%= ErrorHelpers.error_tag(f, :temporal) %>
              </div>

              <div class="metadata-form__language">
                <%= label(f, :language, DisplayNames.get(:language), class: "label") %>
                <%= select(f, :language, get_language_options(), value: get_language(input_value(f, :language)), class: "select") %>
              </div>

              <div class="metadata-form__homepage">
                <%= label(f, :homepage, DisplayNames.get(:homepage), class: "label") %>
                <%= text_input(f, :homepage, class: "input") %>
              </div>

              <div class="metadata-form__format">
                <%= label(f, :sourceFormat, DisplayNames.get(:sourceFormat), class: "label label--required") %>
                <%= select(f, :sourceFormat, get_source_format_options(input_value(f, :sourceType)), [class: "select", disabled: @dataset_exists]) %>
                <%= ErrorHelpers.error_tag(f, :sourceFormat, bind_to_input: false) %>
              </div>
            </div>

            <div class="edit-button-group form-grid">
              <div class="edit-button-group__cancel-btn">
                <button type="button" class="btn btn--large" phx-click="cancel-edit">Cancel</button>
              </div>

              <div class="edit-button-group__save-btn">
                <a href="#data_dictionary_form" id="next-button" class="btn btn--next btn--large btn--action" phx-click="toggle-component-visibility" phx-value-component-expand="data_dictionary_form">Next</a>
                <button id="save-button" name="save-button" class="btn btn--save btn--large" type="button" phx-click="save">Save Draft</button>
              </div>
            </div>
          </div>
        </form>
      </div>
    </div>
    """
  end

  def handle_event(
        "validate",
        %{"form_data" => form_data, "_target" => ["form_data", "dataTitle" | _]},
        %{assigns: %{dataset_exists: false}} = socket
      ) do
    form_data
    |> FormTools.adjust_data_name()
    |> MetadataFormSchema.changeset_from_form_data()
    |> complete_validation(socket)
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    form_data
    |> MetadataFormSchema.changeset_from_form_data()
    |> complete_validation(socket)
  end

  def handle_info(
        %{topic: "toggle-visibility", payload: %{expand: "metadata_form", dataset_id: dataset_id}},
        %{assigns: %{dataset_id: dataset_id}} = socket
      ) do
    {:noreply, assign(socket, visibility: "expanded") |> update_validation_status()}
  end

  def handle_info(%{topic: "toggle-visibility"}, socket) do
    {:noreply, socket}
  end

  defp complete_validation(changeset, socket) do
    new_changeset = Map.put(changeset, :action, :update)
    send(socket.parent_pid, :form_update)

    {:noreply, assign(socket, changeset: new_changeset) |> update_validation_status()}
  end

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} -> [key: description, value: actual_value] end)
  end

  ## TODO: Make these not repeated
  defp rating_selection_prompt(), do: "Please Select a Value"

  defp get_language_options(), do: map_to_dropdown_options(Options.language())
  defp get_level_of_access_options, do: map_to_dropdown_options(Options.level_of_access())
  defp get_rating_options(), do: map_to_dropdown_options(Options.ratings())
  defp get_source_type_options(), do: map_to_dropdown_options(Options.source_type())
  defp get_org_options(), do: Options.organizations(OrgStore.get_all())

  defp get_source_format_options(source_type) when source_type in ["remote", "host"] do
    Options.source_format_extended()
  end

  defp get_source_format_options(_), do: Options.source_format()

  defp get_language(nil), do: "english"
  defp get_language(lang), do: lang

  defp get_license(nil), do: "https://creativecommons.org/licenses/by/4.0/"
  defp get_license(license), do: license

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
