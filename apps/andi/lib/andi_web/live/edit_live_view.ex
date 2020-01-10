defmodule AndiWeb.EditLiveView do
  use AndiWeb, :live_view

  alias Phoenix.HTML.Link
  alias AndiWeb.DatasetValidator
  alias Andi.InputSchemas.InputConverter

  import Andi
  import SmartCity.Event, only: [dataset_update: 0]
  require Logger

  def render(assigns) do
    ~L"""
    <div class="edit-page">
      <%= f = form_for @changeset, "#", [phx_change: :validate, phx_submit: :save, class: "metadata-form", as: :metadata] %>
        <div class="metadata-form__title">
          <%= label(f, :title, "Title of Dataset", class: "label label--required") %>
          <%= text_input(f, :dataTitle, class: "input") %>
          <%= error_tag(f, :dataTitle) %>
        </div>
        <div class="metadata-form__description">
          <%= label(f, :description, "Description", class: "label label--required") %>
          <%= textarea(f, :description, class: "input textarea") %>
          <%= error_tag(f, :description) %>
        </div>
        <div class="metadata-form__maintainer-name">
          <%= label(f, :contactName, "Maintainer Name", class: "label label--required") %>
          <%= text_input(f, :contactName, class: "input") %>
          <%= error_tag(f, :contactName) %>
        </div>
        <div class="metadata-form__maintainer-email">
          <%= label(f, :contactEmail, "Maintainer Email", class: "label label--required") %>
          <%= text_input(f, :contactEmail, class: "input") %>
          <%= error_tag(f, :contactEmail) %>
        </div>
        <div class="metadata-form__release-date">
          <%= label(f, :issuedDate, "Release Date", class: "label label--required") %>
          <%= date_input(f, :issuedDate, class: "input") %>
          <%= error_tag_live(f, :issuedDate) %>
        </div>
        <div class="metadata-form__license">
          <%= label(f, :license, "License", class: "label label--required") %>
          <%= text_input(f, :license, class: "input") %>
          <%= error_tag(f, :license) %>
        </div>
        <div class="metadata-form__update-frequency">
          <%= label(f, :publishFrequency, "Update Frequency", class: "label label--required") %>
          <%= text_input(f, :publishFrequency, class: "input") %>
          <%= error_tag(f, :publishFrequency) %>
        </div>
        <div class="metadata-form__keywords">
          <%= label(f, :keywords, "Keywords", class: "label") %>
          <%= text_input(f, :keywords, value: keywords_to_string(input_value(f, :keywords)), class: "input") %>
          <div class="label label--inline">Separated by comma</div>
        </div>
        <div class="metadata-form__last-updated">
          <%= label(f, :modifiedDate, "Last Updated", class: "label") %>
          <%= date_input(f, :modifiedDate, class: "input") %>
        </div>
        <div class="metadata-form__spatial">
          <%= label(f, :spatial, "Spatial Boundaries", class: "label") %>
          <%= text_input(f, :spatial, class: "input") %>
        </div>
        <div class="metadata-form__temporal">
          <%= label(f, :temporal, "Temporal Boundaries", class: "label") %>
          <%= text_input(f, :temporal, class: "input") %>
          <%= error_tag(f, :temporal) %>
        </div>
        <div class="metadata-form__organization">
          <%= label(f, :orgTitle, "Organization", class: "label label--required") %>
          <%= text_input(f, :orgTitle, [class: "input input--text", readonly: true]) %>
          <%= error_tag(f, :orgTitle) %>
        </div>
        <div class="metadata-form__language">
          <%= label(f, :language, "Language", class: "label") %>
          <%= select(f, :language, get_language_options(), value: get_language(input_value(f, :language)), class: "select") %>
        </div>
        <div class="metadata-form__homepage">
          <%= label(f, :homepage, "Data Homepage URL", class: "label") %>
          <%= text_input(f, :homepage, class: "input") %>
        </div>
        <div class="metadata-form__format">
          <%= label(f, :sourceFormat, "Format", class: "label label--required") %>
          <%= text_input(f, :sourceFormat, [class: "input--text input", readonly: true]) %>
          <%= error_tag(f, :sourceFormat) %>
        </div>
        <div class="metadata-form__level-of-access">
          <%= label(f, :private, "Level of Access", class: "label label--required") %>
          <%= select(f, :private, get_level_of_access_options(), class: "select") %>
          <%= error_tag(f, :private) %>
        </div>
        <div class="metadata-form__cancel-btn">
          <%= Link.button("Cancel", to: "/", method: "get", class: "btn btn--cancel") %>
        </div>
        <div class="metadata-form__save-btn">
          <%= unless is_nil(@validation_errors) do %>
            <div class="metadata__error-message">
              <span>There were errors with the dataset you tried to submit.
              <ul>
                <%= for error <- @validation_errors do %>
                  <li><%= error %></li>
                <% end %>
              </ul>
            </div>
          <% end %>
          <%= Link.button("Next", to: "/", method: "get", id: "next-button", class: "btn btn--next", disabled: true, title: "Not implemented yet.") %>
          <%= submit("Save", id: "save-button", class: "btn btn--save") %>
        </div>
      </form>
      </div>
      <%= if @save_success do %>
        <div id="success-message" class="metadata__success-message">Saved Successfully</div>
      <% end %>

    """
  end

  def mount(%{dataset: dataset}, socket) do
    new_changeset = InputConverter.changeset_from_struct(dataset)

    {:ok,
     assign(socket,
       dataset: dataset,
       changeset: new_changeset,
       validation_errors: nil,
       save_success: false
     )}
  end

  def handle_event("validate", %{"metadata" => form_data}, socket) do
    socket = reset_save_success(socket)

    new_changeset =
      form_data
      |> InputConverter.form_changeset()
      |> Map.put(:action, :update)

    {:noreply, assign(socket, changeset: new_changeset)}
  end

  def handle_event("save", %{"metadata" => form_data}, socket) do
    socket = reset_save_success(socket)

    new_changeset = InputConverter.form_changeset(form_data)

    IO.inspect(new_changeset, label: "WAT")

    # TODO: consider extracting to shared service for API and live-view save
    if new_changeset.valid? do
      # TODO: find out why an empty description doesn't show as a "change"
      schema = Ecto.Changeset.apply_changes(new_changeset) |> IO.inspect(label: "form")
      original_dataset = socket.assigns.dataset

      with dataset = InputConverter.restruct(schema, original_dataset) |> IO.inspect(label: "dataset being saved"),
           :valid <- DatasetValidator.validate(dataset),
           :ok <- Brook.Event.send(instance_name(), dataset_update(), :andi, dataset) do
        {:noreply, assign(socket, dataset: dataset, changeset: new_changeset, save_success: true)}
      else
        {:invalid, errors} ->
          Logger.warn("Unable to create new SmartCity.Dataset: #{inspect({:invalid, errors})}")

          {:noreply, assign(socket, changeset: new_changeset, validation_errors: errors)}

        {:error, e} ->
          Logger.warn("Unable to create new SmartCity.Dataset: #{inspect({:error, e})}")

          {:noreply, assign(socket, changeset: new_changeset)}
      end
    else
      {:noreply, assign(socket, changeset: %{new_changeset | action: :save})}
    end
  end

  defp reset_save_success(socket), do: assign(socket, save_success: false)

  defp get_language_options, do: [[key: "English", value: "english"], [key: "Spanish", value: "spanish"]]
  defp get_level_of_access_options, do: [[key: "Private", value: "true"], [key: "Public", value: "false"]]

  defp keywords_to_string(nil), do: ""
  defp keywords_to_string(keywords) when is_binary(keywords), do: keywords
  defp keywords_to_string(keywords), do: Enum.join(keywords, ", ")

  defp get_language(nil), do: "english"
  defp get_language(lang), do: lang
end
