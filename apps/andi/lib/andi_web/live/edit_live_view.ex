defmodule AndiWeb.EditLiveView do
  use AndiWeb, :live_view

  alias Phoenix.HTML.Link
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.DisplayNames

  import Andi
  import SmartCity.Event, only: [dataset_update: 0]
  require Logger

  def render(assigns) do
    ~L"""
    <div class="edit-page">
      <%= f = form_for @changeset, "#", [phx_change: :validate, phx_submit: :save, class: "metadata-form", as: :metadata] %>
        <div class="metadata-form__title">
          <%= label(f, :title, DisplayNames.get(:dataTitle), class: "label label--required") %>
          <%= text_input(f, :dataTitle, class: "input") %>
          <%= error_tag(f, :dataTitle) %>
        </div>
        <div class="metadata-form__description">
          <%= label(f, :description, DisplayNames.get(:description), class: "label label--required") %>
          <%= textarea(f, :description, class: "input textarea") %>
          <%= error_tag(f, :description) %>
        </div>
        <div class="metadata-form__maintainer-name">
          <%= label(f, :contactName, DisplayNames.get(:contactName), class: "label label--required") %>
          <%= text_input(f, :contactName, class: "input") %>
          <%= error_tag(f, :contactName) %>
        </div>
        <div class="metadata-form__maintainer-email">
          <%= label(f, :contactEmail, DisplayNames.get(:contactEmail), class: "label label--required") %>
          <%= text_input(f, :contactEmail, class: "input") %>
          <%= error_tag(f, :contactEmail) %>
        </div>
        <div class="metadata-form__release-date">
          <%= label(f, :issuedDate, DisplayNames.get(:issuedDate), class: "label label--required") %>
          <%= date_input(f, :issuedDate, class: "input") %>
          <%= error_tag_live(f, :issuedDate) %>
        </div>
        <div class="metadata-form__license">
          <%= label(f, :license, DisplayNames.get(:license), class: "label label--required") %>
          <%= text_input(f, :license, class: "input") %>
          <%= error_tag(f, :license) %>
        </div>
        <div class="metadata-form__update-frequency">
          <%= label(f, :publishFrequency, DisplayNames.get(:publishFrequency), class: "label label--required") %>
          <%= text_input(f, :publishFrequency, class: "input") %>
          <%= error_tag(f, :publishFrequency) %>
        </div>
        <div class="metadata-form__keywords">
          <%= label(f, :keywords, DisplayNames.get(:keywords), class: "label") %>
          <%= text_input(f, :keywords, value: keywords_to_string(input_value(f, :keywords)), class: "input") %>
          <div class="label label--inline">Separated by comma</div>
        </div>
        <div class="metadata-form__last-updated">
          <%= label(f, :modifiedDate, DisplayNames.get(:modifiedDate), class: "label") %>
          <%= date_input(f, :modifiedDate, class: "input") %>
        </div>
        <div class="metadata-form__spatial">
          <%= label(f, :spatial, DisplayNames.get(:spatial), class: "label") %>
          <%= text_input(f, :spatial, class: "input") %>
        </div>
        <div class="metadata-form__temporal">
          <%= label(f, :temporal, DisplayNames.get(:temporal), class: "label") %>
          <%= text_input(f, :temporal, class: "input") %>
          <%= error_tag(f, :temporal) %>
        </div>
        <div class="metadata-form__organization">
          <%= label(f, :orgTitle, DisplayNames.get(:orgTitle), class: "label label--required") %>
          <%= text_input(f, :orgTitle, [class: "input input--text", readonly: true]) %>
          <%= error_tag(f, :orgTitle) %>
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
          <%= text_input(f, :sourceFormat, [class: "input--text input", readonly: true]) %>
          <%= error_tag(f, :sourceFormat) %>
        </div>
        <div class="metadata-form__level-of-access">
          <%= label(f, :private, DisplayNames.get(:private), class: "label label--required") %>
          <%= select(f, :private, get_level_of_access_options(), class: "select") %>
          <%= error_tag(f, :private) %>
        </div>
        <div class="metadata-form__benefit-rating">
          <%= label(f, :benefitRating, DisplayNames.get(:benefitRating), class: "label label--required") %>
          <%= select(f, :benefitRating, get_rating_options(), class: "select", prompt: rating_selection_prompt()) %>
          <%= error_tag_live(f, :benefitRating) %>
        </div>
        <div class="metadata-form__risk-rating">
          <%= label(f, :riskRating, DisplayNames.get(:riskRating), class: "label label--required") %>
          <%= select(f, :riskRating, get_rating_options(), class: "select", prompt: rating_selection_prompt()) %>
          <%= error_tag_live(f, :riskRating) %>
        </div>
        <div class="metadata-form__cancel-btn">
          <%= Link.button("Cancel", to: "/", method: "get", class: "btn btn--cancel") %>
        </div>
        <div class="metadata-form__save-btn">
          <%= Link.button("Next", to: "/", method: "get", id: "next-button", class: "btn btn--next", disabled: true, title: "Not implemented yet.") %>
          <%= submit("Save", id: "save-button", class: "btn btn--save") %>
        </div>
      </form>
      </div>
      <%= if @save_success do %>
        <div id="success-message" class="metadata__success-message">Saved Successfully</div>
      <% end %>
      <%= if @has_validation_errors do %>
        <div class="metadata__error-message">There were errors with the dataset you tried to submit.</div>
      <% end %>
    """
  end

  def mount(%{dataset: dataset}, socket) do
    new_changeset = InputConverter.changeset_from_dataset(dataset)

    {:ok,
     assign(socket,
       dataset: dataset,
       changeset: new_changeset,
       has_validation_errors: false,
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
    original_dataset = socket.assigns.dataset
    changeset = InputConverter.changeset_from_dataset(original_dataset, form_data)

    if changeset.valid? do
      changes = Ecto.Changeset.apply_changes(changeset)

      with dataset = InputConverter.restruct(changes, original_dataset),
           :ok <- Brook.Event.send(instance_name(), dataset_update(), :andi, dataset) do
        {:noreply, assign(socket, dataset: dataset, changeset: changeset, save_success: true)}
      else
        error ->
          Logger.warn("Unable to create new SmartCity.Dataset: #{inspect(error)}")

          {:noreply, assign(socket, changeset: changeset)}
      end
    else
      {:noreply, assign(socket, changeset: %{changeset | action: :save}, has_validation_errors: true)}
    end
  end

  defp reset_save_success(socket), do: assign(socket, save_success: false, has_validation_errors: false)

  defp get_language_options, do: [[key: "English", value: "english"], [key: "Spanish", value: "spanish"]]
  defp get_level_of_access_options, do: [[key: "Private", value: "true"], [key: "Public", value: "false"]]
  defp get_rating_options, do: [[key: "Low", value: 0.0], [key: "Medium", value: 0.5], [key: "High", value: 1.0]]

  defp keywords_to_string(nil), do: ""
  defp keywords_to_string(keywords) when is_binary(keywords), do: keywords
  defp keywords_to_string(keywords), do: Enum.join(keywords, ", ")

  defp get_language(nil), do: "english"
  defp get_language(lang), do: lang

  defp rating_selection_prompt(), do: "Please Select a Value"
end
