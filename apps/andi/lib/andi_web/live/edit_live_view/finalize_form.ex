defmodule AndiWeb.EditLiveView.FinalizeForm do
  @moduledoc """
  LiveComponent for scheduling dataset ingestion
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  alias Phoenix.HTML.Link
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.FormTools
  alias AndiWeb.ErrorHelpers

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
    cadence = input_value(assigns.form, :cadence)
    scheduler_data = Map.put_new(assigns.scheduler_data, "cadence_type", determine_cadence_type(cadence))

    repeating_schedule = to_repeating(scheduler_data["cadence_type"], cadence)
    default_future_schedule = cronlist_to_future_schedule(repeating_schedule)
    scheduler_data = Map.merge(
      default_future_schedule,
      scheduler_data
    )

    updated_assigns =
      assigns
      |> Map.put(:repeating_schedule, repeating_schedule)
      |> Map.put(:scheduler_data, scheduler_data)

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
        <div class="component-edit-section--<%= @visibility %>">
          <div class="finalize-form-edit-section form-grid">
            <div "finalize-form__schedule">
              <h3>Schedule Ingestion</h3>
              <div class="finalize-form__schedule-options">
                <div class="finalize-form__schedule-option">
                  <%= radio_button(:scheduler, :cadence_type, "once", checked: @scheduler_data["cadence_type"] == "once")%>
                  <%= label(:scheduler, :cadence_type, "Immediately", class: "finalize-form__schedule-option-label") %>
                </div>
                <div class="finalize-form__schedule-option">
                  <%= radio_button(:scheduler, :cadence_type, "future", checked: @scheduler_data["cadence_type"] == "future") %>
                  <%= label(:scheduler, :cadence_type, "Future", class: "finalize-form__schedule-option-label") %>
                </div>
                <div class="finalize-form__schedule-option">
                  <%= radio_button(:scheduler, :cadence_type, "never", checked: @scheduler_data["cadence_type"] == "never") %>
                  <%= label(:scheduler, :cadence_type, "Never", class: "finalize-form__schedule-option-label") %>
                </div>
                <div class="finalize-form__schedule-option">
                  <%= radio_button(:scheduler, :cadence_type, "repeating", checked: @scheduler_data["cadence_type"] == "repeating") %>
                  <%= label(:scheduler, :cadence_type, "Repeating", class: "finalize-form__schedule-option-label") %>
                </div>
              </div>
              <%= hidden_input(@form, :cadence) %>
              <%= if @scheduler_data["cadence_type"] == "repeating", do: repeating_scheduler_form(%{repeating_schedule: @repeating_schedule, myself: @myself}) %>
              <%= if @scheduler_data["cadence_type"] == "future" do %>
                <%= future_scheduler_form(%{scheduler_data: @scheduler_data}) %>
              <%= else %>
                <%= hidden_input(:scheduler, :future_date, value: @scheduler_data["future_date"]) %>
                <%= hidden_input(:scheduler, :future_time, value: @scheduler_data["future_time"]) %>
              <% end %>
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
      </div>
    </div>
    """
  end

  defp future_scheduler_form(assigns) do
    ~L"""
      <div class="finalize-form__scheduler--visible">
        <div class="finalize-form__future-schedule">
          <%= label(:scheduler, :future_date, "Date of Future Ingestion") %>
          <%= date_input(:scheduler, :future_date, value: @scheduler_data["future_date"]) %>
          <%= label(:scheduler, :future_time, "Time of Future Ingestion") %>
          <%= time_input(:scheduler, :future_time, value: @scheduler_data["future_time"], precision: :second, step: 15) %>
        </div>
      </div>
    """
  end

  defp repeating_scheduler_form(assigns) do
    ~L"""
      <div class="finalize-form__scheduler--visible">
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
            <label>Second</label>
            <input class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-value-input-field="second" phx-target="<%= @myself %>" value="<%= @repeating_schedule[:second] %>" />

          </div>
          <div class="finalize-form__schedule-input-field">
            <label>Minute</label>
            <input class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-value-input-field="minute" phx-target="<%= @myself %>" value="<%= @repeating_schedule[:minute] %>" />
          </div>
          <div class="finalize-form__schedule-input-field">
            <label>Hour</label>
            <input class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-value-input-field="hour" phx-target="<%= @myself %>" value="<%= @repeating_schedule[:hour] %>" />
          </div>
          <div class="finalize-form__schedule-input-field">
            <label>Day</label>
            <input class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-value-input-field="day" phx-target="<%= @myself %>" value="<%= @repeating_schedule[:day] %>" />
          </div>
          <div class="finalize-form__schedule-input-field">
            <label>Month</label>
            <input class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-value-input-field="month" phx-target="<%= @myself %>" value="<%= @repeating_schedule[:month] %>" />
          </div>
          <div class="finalize-form__schedule-input-field">
            <label>Week</label>
            <input class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-value-input-field="week" phx-target="<%= @myself %>" value="<%= @repeating_schedule[:week] %>" />
          </div>
        </div>
      </div>
    """
  end

  def handle_event("set_schedule", %{"input-field" => input_field, "value" => value}, socket) do
    new_repeating_schedule = Map.put(socket.assigns.repeating_schedule, String.to_existing_atom(input_field), value)
    new_cron = cronlist_to_cronstring!(new_repeating_schedule)

    Datasets.update_cadence(socket.assigns.dataset_id, new_cron)
    send(self(), {:assign_crontab})

    {:noreply, assign(socket, repeating_schedule: new_repeating_schedule)}
  end

  def handle_event("quick_schedule", %{"schedule" => schedule}, socket) do
    cronstring = @quick_schedules[schedule]
    Datasets.update_cadence(socket.assigns.dataset_id, cronstring)
    send(self(), {:assign_crontab})

    {:noreply, assign(socket, repeating_schedule: cronstring_to_cronlist!(cronstring))}
  end

  def update_form_with_schedule(%{"cadence_type" => cadence_type} = _sd, form_data) when cadence_type in ["once", "never"], do: put_in(form_data, ["technical", "cadence"], cadence_type)
  def update_form_with_schedule(%{"cadence_type" => "future"} = sd, form_data) do
    date = Map.get(sd, "future_date", "")
    time = Map.get(sd, "future_time", "")

    case date_and_time_to_cronstring(date, time) do
      {:ok, cronstring} -> put_in(form_data, ["technical", "cadence"], cronstring)
      {:error, _} -> put_in(form_data, ["technical", "cadence"], "")
    end
  end
  def update_form_with_schedule(_sd, form_data), do: form_data
end
