defmodule AndiWeb.EditLiveView do
  use Phoenix.LiveView
  alias Phoenix.HTML.Form
  alias Phoenix.HTML.Link
  import AndiWeb.ErrorHelpers
  import Andi
  import SmartCity.Event, only: [dataset_update: 0]

  def render(assigns) do
    ~L"""
    <div class="edit-page">
      <%= f = Form.form_for @changeset, "#", [phx_change: :validate, phx_submit: :save, class: "metadata-form"] %>
          <%= Form.inputs_for f, :business, fn fp -> %>
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
            <div class="metadata-form__release-date">
              <%= Form.label(fp, :issuedDate, "Release Date", class: "label label--required") %>
              <%= Form.text_input(fp, :issuedDate, class: "input") %>
              <%= error_tag(fp, :issuedDate) %>
            </div>
            <div class="metadata-form__license">
              <%= Form.label(fp, :license, "License", class: "label label--required") %>
              <%= Form.text_input(fp, :license, class: "input") %>
              <%= error_tag(fp, :license) %>
            </div>
            <div class="metadata-form__update-frequency">
              <%= Form.label(fp, :publishFrequency, "Update Frequency", class: "label label--required") %>
              <%= Form.text_input(fp, :publishFrequency, class: "input") %>
              <%= error_tag(fp, :publishFrequency) %>
            </div>
            <div class="metadata-form__keywords">
              <%= Form.label(fp, :keywords, "Keywords", class: "label") %>
              <%= Form.text_input(fp, :keywords, value: get_keywords(Form.input_value(fp, :keywords)), class: "input") %>
              <div class="label label--inline">Separated by comma</div>
            </div>
            <div class="metadata-form__last-updated">
              <%= Form.label(fp, :modifiedDate, "Last Updated", class: "label") %>
              <%= Form.text_input(fp, :modifiedDate, class: "input") %>
            </div>
            <div class="metadata-form__spatial">
              <%= Form.label(fp, :spatial, "Spatial Boundaries", class: "label") %>
              <%= Form.text_input(fp, :spatial, class: "input") %>
            </div>
            <div class="metadata-form__temporal">
              <%= Form.label(fp, :temporal, "Temporal Boundaries", class: "label") %>
              <%= Form.text_input(fp, :temporal, class: "input") %>
              <%= error_tag(fp, :temporal) %>
            </div>
            <div class="metadata-form__organization">
              <%= Form.label(fp, :orgTitle, "Organization", class: "label label--required") %>
              <%= Form.text_input(fp, :orgTitle, [class: "input input--text", readonly: true]) %>
              <%= error_tag(fp, :orgTitle) %>
            </div>
            <div class="metadata-form__language">
              <%= Form.label(fp, :language, "Language", class: "label") %>
              <%= Form.select(fp, :language, get_language_options(), value: get_language(Form.input_value(fp, :language)), class: "select") %>
            </div>
            <div class="metadata-form__homepage">
              <%= Form.label(fp, :homepage, "Data Homepage URL", class: "label") %>
              <%= Form.text_input(fp, :homepage, class: "input") %>
            </div>
          <% end %>
          <%= Form.inputs_for f, :technical, fn fp -> %>
            <div class="metadata-form__format">
              <%= Form.label(fp, :sourceFormat, "Format", class: "label label--required") %>
              <%= Form.text_input(fp, :sourceFormat, [class: "input--text input", readonly: true]) %>
              <%= error_tag(fp, :sourceFormat) %>
            </div>
            <div class="metadata-form__level-of-access">
              <%= Form.label(fp, :private, "Level of Access", class: "label label--required") %>
              <%= Form.select(fp, :private, get_level_of_access_options(), class: "select") %>
              <%= error_tag(fp, :private) %>
            </div>
          <% end %>
        <div class="metadata-form__cancel-btn">
          <%= Link.button("Cancel", to: "/", method: "get", class: "btn btn--cancel") %>
        </div>
        <div class="metadata-form__save-btn">
          <%= Link.button("Next", to: "#", id: "next-button", class: "btn btn--next") %>
          <%= Form.submit("Save", id: "save-button", class: "btn btn--save") %>
        </div>
      </div>
      <div>
        <%= if @is_saved do %>
          <div id="success-message" class="metadata__success-message">Saved Successfully</div>
        <% end %>
      </div>

    """
  end

  def mount(%{dataset: dataset}, socket) do
    {:ok,
     assign(socket, id: dataset.id, dataset: dataset, changeset: Andi.DatasetSchema.changeset(dataset), is_saved: false)}
  end

  def handle_event(
        "validate",
        %{"dataset_schema" => dataset_schema} = event,
        socket
      ) do
    {:noreply, assign(socket, changeset: apply_changes(dataset_schema), is_saved: false)}
  end

  def handle_event("save", %{"dataset_schema" => dataset_schema} = event, socket) do
    change = apply_changes(dataset_schema)

    case change.valid? do
      true ->
        schema = Ecto.Changeset.apply_changes(change)
        original_dataset = socket.assigns.dataset

        %{
          original_dataset
          | business: Map.merge(Map.from_struct(original_dataset.business), Map.from_struct(schema.business)),
            technical: Map.merge(Map.from_struct(original_dataset.technical), Map.from_struct(schema.technical))
        }
        |> SmartCity.Dataset.new()
        |> send_dataset_update

        {:noreply, assign(socket, changeset: change, is_saved: true, update_stepper_state: "meta-data-save")}

      false ->
        {:noreply, assign(socket, changeset: change, is_saved: false, display_errors: true)}
    end
  end

  defp apply_changes(data) do
    data
    |> put_in(["business", "keywords"], get_keywords_as_list(data["business"]["keywords"]))
    |> Andi.DatasetSchema.changeset()
  end

  defp send_dataset_update({:ok, dataset}) do
    Brook.Event.send(instance_name(), dataset_update(), :andi, dataset)
  end

  defp send_dataset_update({:error, e}), do: {:error, e}

  defp get_language_options, do: [[key: "English", value: "english"], [key: "Spanish", value: "spanish"]]
  defp get_level_of_access_options, do: [[key: "Private", value: "true"], [key: "Public", value: "false"]]

  defp get_keywords(nil), do: ""
  defp get_keywords(keywords), do: Enum.join(keywords, ", ")

  defp get_keywords_as_list(keywords) when is_list(keywords), do: keywords

  defp get_keywords_as_list(keywords) when is_binary(keywords) do
    keywords |> String.split(", ") |> Enum.map(&String.trim/1)
  end

  defp get_language(nil), do: "english"
  defp get_language(lang), do: lang
end
