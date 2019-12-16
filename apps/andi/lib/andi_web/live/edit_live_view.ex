defmodule AndiWeb.EditLiveView do
  use Phoenix.LiveView
  alias Phoenix.HTML.Form
  alias Phoenix.HTML.Link
  import AndiWeb.ErrorHelpers
  import Andi
  import SmartCity.Event, only: [dataset_update: 0]
  require Logger

  def render(assigns) do
    ~L"""
    <div class="edit-page">
      <%= f = Form.form_for @changeset, "#", [phx_change: :validate, phx_submit: :save, class: "metadata-form"] %>
          <%= Form.inputs_for f, :business, fn fp -> %>
            <div class="metadata-form__spatial">
              <%= Form.label(fp, :spatial, "Spatial Boundaries", class: "label") %>
              <%= Form.text_input(fp, :spatial, class: "input") %>
            </div>
            <div class="metadata-form__last-updated">
              <%= Form.label(fp, :modifiedDate, "Last Updated", class: "label") %>
              <%= Form.text_input(fp, :modifiedDate, class: "input") %>
            </div>
            <div class="metadata-form__keywords">
              <%= Form.label(fp, :keywords, "Keywords", class: "label") %>
              <%= Form.text_input(fp, :keywords, value: get_keywords(Form.input_value(fp, :keywords)), class: "input") %>
              <div class="label label--inline">Separated by comma</div>
            </div>
            <div class="metadata-form__update-frequency">
              <%= Form.label(fp, :publishFrequency, "Update Frequency", class: "label label--required") %>
              <%= Form.text_input(fp, :publishFrequency, class: "input") %>
              <%= error_tag(fp, :publishFrequency) %>
            </div>
            <div class="metadata-form__license">
              <%= Form.label(fp, :license, "License", class: "label label--required") %>
              <%= Form.text_input(fp, :license, class: "input") %>
              <%= error_tag(fp, :license) %>
            </div>
            <div class="metadata-form__release-date">
              <%= Form.label(fp, :issuedDate, "Release Date", class: "label label--required") %>
              <%= Form.text_input(fp, :issuedDate, class: "input") %>
              <%= error_tag(fp, :issuedDate) %>
            </div>
            <div class="metadata-form__title">
              <%= Form.label(fp, :title, "Title of Dataset", class: "label label--required") %>
              <%= Form.text_input(fp, :dataTitle, class: "input") %>
              <%= error_tag(fp, :dataTitle) %>
            </div>
            <div class="metadata-form__description">
              <%= Form.label(fp, :description, "Description", class: "label label--required") %>
              <%= Form.textarea(fp, :description, class: "input textarea") %>
              <%= error_tag(fp, :description) %>
            </div>
            <div class="metadata-form__maintainer-name">
              <%= Form.label(fp, :contactName, "Maintainer Name", class: "label label--required") %>
              <%= Form.text_input(fp, :contactName, class: "input") %>
              <%= error_tag(fp, :contactName) %>
            </div>
            <div class="metadata-form__maintainer-email">
              <%= Form.label(fp, :contactEmail, "Maintainer Email", class: "label label--required") %>
              <%= Form.text_input(fp, :contactEmail, class: "input") %>
              <%= error_tag(fp, :contactEmail) %>
            </div>
            <div class="metadata-form__temporal">
              <%= Form.label(fp, :temporal, "Temporal Boundaries", class: "label") %>
              <%= Form.text_input(fp, :temporal, class: "input") %>
              <%= error_tag(fp, :temporal) %>
            </div>
            <div class="metadata-form__organization">
              <%= Form.label(fp, :orgTitle, "Organization", class: "label label--required") %>
              <%= Form.text_input(fp, :orgTitle, [class: "input input--text", disabled: true]) %>
              <%= error_tag(fp, :orgTitle) %>
            </div>
            <div class="metadata-form__language">
              <%= Form.label(fp, :language, "Language", class: "label") %>
              <%= Form.select(fp, :language, [[key: "English", value: "english"], [key: "Spanish", value: "spanish"]], value: get_language(Form.input_value(fp, :language)), class: "select") %>
            </div>
            <div class="metadata-form__homepage">
              <%= Form.label(fp, :homepage, "Data Homepage URL", class: "label") %>
              <%= Form.text_input(fp, :homepage, class: "input") %>
            </div>
          <% end %>
          <%= Form.inputs_for f, :technical, fn fp -> %>
            <div class="metadata-form__level-of-access">
              <%= Form.label(fp, :private, "Level of Access", class: "label label--required") %>
              <%= Form.select(fp, :private, [[key: "Private", value: "true"], [key: "Public", value: "false"]], class: "select") %>
              <%= error_tag(fp, :private) %>
            </div>

            <div class="metadata-form__format">
              <%= Form.label(fp, :format, "Format", class: "label label--required") %>
              <%= Form.text_input(fp, :sourceFormat, [class: "input", disabled: true]) %>
              <%= error_tag(fp, :sourceFormat) %>
            </div>
          <% end %>
        <div class="metadata-form__cancel-btn">
          <%= Link.button("Cancel", to: "/", class: "btn btn--cancel") %>
        </div>
        <div class="metadata-form__save-btn">
          <%= Form.submit("Save", id: "save-button", class: "btn btn--save", disabled: false) %>
        </div>
        </div>
      <div>
        <%= if @is_saved do %>
          <div id="success-message" class="div__success-message">Saved Successfully</div>
        <% end %>
      </div>

    """
  end

  def mount(%{dataset: dataset}, socket) do
    new_business = dataset.business |> Map.from_struct()
    new_technical = dataset.technical |> Map.from_struct()

    change =
      dataset
      |> Map.from_struct()
      |> Map.put(:business, new_business)
      |> Map.put(:technical, new_technical)
      |> Andi.DatasetSchema.changeset()

    {:ok, assign(socket, changeset: change, is_saved: false)}
  end

  def handle_event(
        "validate",
        %{"dataset_schema" => dataset_schema},
        %{assigns: %{changeset: %{changes: existing}}} = socket
      ) do
    keyword_list = get_keywords_as_list(dataset_schema["business"]["keywords"])

    dataset_schema =
      dataset_schema
      |> put_in(["business", "keywords"], keyword_list)
      |> put_in(["technical", "sourceFormat"], existing.technical.changes.sourceFormat)
      |> put_in(["business", "orgTitle"], existing.business.changes.orgTitle)

    change = Andi.DatasetSchema.changeset(dataset_schema)
    {:noreply, assign(socket, changeset: change, is_saved: false)}
  end

  def handle_event("save", _event, socket) do
    is_saved =
      case get_all_errors(socket.assigns.changeset) do
        [] ->
          schema = Ecto.Changeset.apply_changes(socket.assigns.changeset)
          bus_map = schema.business |> Map.from_struct()
          tech_map = schema.technical |> Map.from_struct()

          {:ok, dataset} =
            schema
            |> Map.from_struct()
            |> Map.put(:business, bus_map)
            |> Map.put(:technical, tech_map)
            |> SmartCity.Dataset.new()

          Brook.Event.send(instance_name(), dataset_update(), :andi, dataset)
          Logger.debug("Saved #{schema.id}")
          true

        errors ->
          dataset = Ecto.Changeset.apply_changes(socket.assigns.changeset)
          Logger.info("Could not save dataset #{dataset.id} because it had errors: #{inspect(errors)}")
          false
      end

    # Show errors is an unused property. It's sole purpose is to tell live view there has been a change so that it will render errors if needed.
    {:noreply, assign(socket, is_saved: is_saved, show_errors: true)}
  end

  defp get_keywords(nil), do: ""
  defp get_keywords(keywords), do: Enum.join(keywords, ", ")

  defp get_keywords_as_list(keywords) when is_list(keywords), do: keywords

  defp get_keywords_as_list(keywords) when is_binary(keywords) do
    keywords |> String.split(", ") |> Enum.map(&String.trim/1)
  end

  defp get_language(nil), do: "english"
  defp get_language(lang), do: lang

  defp get_all_errors(changeset) do
    changeset.errors ++ changeset.changes.technical.errors ++ changeset.changes.business.errors
  end
end
