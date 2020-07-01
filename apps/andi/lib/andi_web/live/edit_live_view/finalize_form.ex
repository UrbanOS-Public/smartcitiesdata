defmodule AndiWeb.EditLiveView.FinalizeForm do
  @moduledoc """
  LiveComponent for scheduling dataset ingestion
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  alias Ecto.Changeset

  alias Phoenix.HTML.Link
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.FormTools
  alias AndiWeb.ErrorHelpers

  alias AndiWeb.InputSchemas.FinalizeForm
  alias Andi.InputSchemas.CronTools
  import Andi.InputSchemas.CronTools

  @quick_schedules %{
    "hourly" => "0 0 * * * *",
    "daily" => "0 0 0 * * *",
    "weekly" => "0 0 0 * * 0",
    "monthly" => "0 0 0 1 * *",
    "yearly" => "0 0 0 1 1 *"
  }

  def mount(socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    IO.inspect(label: "maybe here instead?")
    current_data = case Map.get(assigns, :finalize_form_data) do
      nil -> assigns.form.data
      dater -> dater
    end

    finalize_form_changeset = FinalizeForm.changeset(
      %FinalizeForm{},
      current_data
    )

    updated_assigns =
      assigns
      |> Map.put(:changeset, finalize_form_changeset)

    {:ok, assign(socket, updated_assigns)}
  end

  def render(assigns) do
    action =
      case assigns.visibility do
        "collapsed" -> "EDIT"
        "expanded" -> "MINIMIZE"
      end

    publish_message? = !String.contains?(assigns.success_message, "Saved successfully")

    ~L"""
    <div id="finalize_form" class="finalize-form finalize-form--<%= @visibility %>">
      <div class="component-header" phx-click="toggle-component-visibility" phx-value-component="finalize_form">
        <h3 class="component-number component-number--<%= @visibility %>">4</h3>
        <div class="component-title full-width">
          <h2 class="component-title-text component-title-text--<%= @visibility %> ">Finalize</h2>
          <div class="component-title-action">
            <div class="component-title-action-text--<%= @visibility %>"><%= action %></div>
            <div class="component-title-icon--<%= @visibility %>"></div>
          </div>
        </div>
      </div>

      <div class="form-section">
        <% fin = form_for(@changeset, "#", [as: :finalize_form_data]) %>
        <div class="component-edit-section--<%= @visibility %>">
          <div class="finalize-form-edit-section form-grid">
            <div "finalize-form__schedule">
              <h3>Schedule Ingestion</h3>
              <div class="finalize-form__schedule-options">
                <div class="finalize-form__schedule-option">
                  <%= radio_button(fin, :cadence_type, "once")%>
                  <%= label(fin, :cadence_type, "Immediately", class: "finalize-form__schedule-option-label") %>
                </div>
                <div class="finalize-form__schedule-option">
                  <%= radio_button(fin, :cadence_type, "future") %>
                  <%= label(fin, :cadence_type, "Future", class: "finalize-form__schedule-option-label") %>
                </div>
                <div class="finalize-form__schedule-option">
                  <%= radio_button(fin, :cadence_type, "never") %>
                  <%= label(fin, :cadence_type, "Never", class: "finalize-form__schedule-option-label") %>
                </div>
                <div class="finalize-form__schedule-option">
                  <%= radio_button(fin, :cadence_type, "repeating") %>
                  <%= label(:scheduler, :cadence_type, "Repeating", class: "finalize-form__schedule-option-label") %>
                </div>
              </div>
              <%= hidden_input(@form, :cadence) %>
              <%= future_scheduler_form(%{fin: fin}) %>
              <%= repeating_scheduler_form(%{fin: fin, myself: @myself}) %>
              <%= ErrorHelpers.error_tag(@form, :cadence) %>
            </div>
          </div>

          <div class="edit-button-group form-grid">
            <div class="edit-button-group__cancel-btn">
              <a href="#url-form" id="back-button" class="btn btn--back btn--large" phx-click="toggle-component-visibility" phx-value-component-collapse="finalize_form" phx-value-component-expand="url_form">Back</a>
              <%= Link.button("Cancel", to: "/", method: "get", class: "btn btn--large") %>
            </div>

            <div class="edit-button-group__messages">
              <%= if @save_success and publish_message? do %>
                <div class="metadata__success-message"><%= @success_message %></div>
              <% end %>
              <%= if @has_validation_errors do %>
                <div id="validation-error-message" class="metadata__error-message">There were errors with the dataset you tried to submit.</div>
              <% end %>
              <%= if @page_error do %>
                <div id="page-error-message" class="metadata__error-message">A page error occurred</div>
              <% end %>
            </div>

            <div class="edit-button-group__save-btn">
              <button type="button" id="publish-button" class="btn btn--publish btn--action btn--large" phx-click="publish">Publish</button>
              <%= submit("Save Draft", id: "save-button", name: "save-button", class: "btn btn--save btn--large", phx_value_action: "draft", phx_hook: "showSnackbar") %>
            </div>
          </div>
        </div>
        </form>
      </div>
    </div>
    """
  end

  defp timeout do
"""

"""
  end

  defp future_scheduler_form(assigns) do
    ~L"""
      <% [future] = inputs_for(@fin, :future_schedule) %>
      <div class="finalize-form__scheduler--visible">
      <%= if input_value(@fin, :cadence_type) == "future" do %>
        <div class="finalize-form__future-schedule">
        <%= label(future, :date, "Date of Future Ingestion") %>
        <%= date_input(future, :date) %>
        <%= label(future, :time, "Time of Future Ingestion") %>
        <%= time_input(future, :time, precision: :second, step: 1) %>
        </div>
      <%= else %>
        <%= hidden_input(future, :date) %>
        <%= hidden_input(future, :time) %>
      <% end %>
      </div>
    """
  end

  defp repeating_scheduler_form(assigns) do
    ~L"""
      <% [repeat] = inputs_for(@fin, :repeating_schedule) %>
      <div class="finalize-form__scheduler--visible">
      <%= if input_value(@fin, :cadence_type) == "repeating" do %>
        <h4>Quick Schedule</h4>

        <div class="finalize-form__quick-schedule">
          <button type="button" class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="hourly" phx-target="<%= @myself %>">Hourly</button>
          <button type="button" class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="daily" phx-target="<%= @myself %>">Daily</button>
          <button type="button" class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="weekly" phx-target="<%= @myself %>">Weekly</button>
          <button type="button" class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="monthly" phx-target="<%= @myself %>">Monthly</button>
          <button type="button" class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="yearly" phx-target="<%= @myself %>">Yearly</button>
        </div>

        <div class="finalize-form__help-link">
          <a href="https://en.wikipedia.org/wiki/Cron" target="_blank">Cron Schedule Help</a>
        </div>

        <div class="finalize-form__schedule-input">
          <div class="finalize-form__schedule-input-field">
            <%= label(repeat, :second, "Second") %>
            <%= text_input(repeat, :second) %>
          </div>
          <div class="finalize-form__schedule-input-field">
            <%= label(repeat, :minute, "Minute") %>
            <%= text_input(repeat, :minute) %>
          </div>
          <div class="finalize-form__schedule-input-field">
            <%= label(repeat, :hour, "Hour") %>
            <%= text_input(repeat, :hour) %>
          </div>
          <div class="finalize-form__schedule-input-field">
            <%= label(repeat, :day, "Day") %>
            <%= text_input(repeat, :day) %>
          </div>
          <div class="finalize-form__schedule-input-field">
            <%= label(repeat, :month, "Month") %>
            <%= text_input(repeat, :month) %>
          </div>
          <div class="finalize-form__schedule-input-field">
            <%= label(repeat, :week, "Week") %>
            <%= text_input(repeat, :week) %>
          </div>
        </div>
        <%= else %>
          <%= hidden_input(repeat, :second) %>
          <%= hidden_input(repeat, :minute) %>
          <%= hidden_input(repeat, :hour) %>
          <%= hidden_input(repeat, :day) %>
          <%= hidden_input(repeat, :month) %>
          <%= hidden_input(repeat, :week) %>
        <% end %>
      </div>
    """
  end

  def handle_event("quick_schedule", %{"schedule" => schedule}, socket) do
    cronlist = @quick_schedules[schedule]
    |> CronTools.cronstring_to_cronlist!()

    changeset = socket.assigns.changeset
    |> Changeset.put_change(:repeating_schedule, cronlist)
    |> Map.put(:action, :update)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def update_form_with_schedule(%{"cadence_type" => cadence_type} = _sd, form_data) when cadence_type in ["once", "never"], do: put_in(form_data, ["technical", "cadence"], cadence_type)
  def update_form_with_schedule(%{"cadence_type" => "future"} = ff, form_data) do
    changeset = FinalizeForm.changeset(%FinalizeForm{}, ff)

    if changeset.changes.future_schedule.valid? do
      %{"date" => date, "time" => time} = Map.get(ff, "future_schedule")
      cronstring = CronTools.date_and_time_to_cronstring!(date, time)
      put_in(form_data, ["technical", "cadence"], cronstring)
    else
      put_in(form_data, ["technical", "cadence"], "")
    end
  end
  def update_form_with_schedule(%{"cadence_type" => "repeating"} = sd, form_data) do
    cronstring = Map.get(sd, "repeating_schedule", %{})
    |> CronTools.cronlist_to_cronstring!()

    put_in(form_data, ["technical", "cadence"], cronstring)
  end
  def update_form_with_schedule(_sd, form_data), do: form_data
end
