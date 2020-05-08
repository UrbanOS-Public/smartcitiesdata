defmodule AndiWeb.EditLiveView.FinalizeForm do
  @moduledoc """
  LiveComponent for scheduling dataset ingestion
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  def mount(socket) do
    {:ok, socket}
  end

  def render(assigns) do
    modifier =
      if assigns.repeat_ingestion? do
        "visible"
      else
        "hidden"
      end

    crontab_list = parse_crontab(assigns.crontab)

    ~L"""
    <div id="<%= @id %>" class="finalize-form form-section">
      <h2 class="edit-page__box-header">Finalize</h2>

      <div "finalize-form__schedule">
        <h3>Schedule Job</h3>

        <div class="finalize-form__schedule-options">
          <div class="finalize-form__schedule-option">
            <%= label(@form, :cadence, "Immediately", class: "finalize-form__schedule-option-label") %>
            <%= radio_button(@form, :cadence, "once") %>
          </div>

          <div class="finalize-form__schedule-option">
            <%= label(@form, :cadence, "Repeat", class: "finalize-form__schedule-option-label") %>
            <%= radio_button(@form, :cadence, @crontab) %>
          </div>
        </div>

        <div class="finalize-form__scheduler--<%= modifier %>">
          <h4>Quick Schedule</h4>

          <div class="finalize-form__quick-schedule">
            <button class="finalize-form-cron-button">Startup</button>
            <button class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="hourly" phx-target="<%= @myself %>">Hourly</button>
            <button class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="daily" phx-target="<%= @myself %>">Daily</button>
            <button class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="weekly" phx-target="<%= @myself %>">Weekly</button>
            <button class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="monthly" phx-target="<%= @myself %>">Monthly</button>
            <button class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="yearly" phx-target="<%= @myself %>">Yearly</button>
          </div>

          <div class="finalize-form__schedule-input">
            <div class="finalize-form__schedule-input-field">
              <label>Second</label>
              <input class="finalize-form-schedule-input__field" value="<%= crontab_list.second %>" />
            </div>
            <div class="finalize-form__schedule-input-field">
              <label>Minute</label>
              <input class="finalize-form-schedule-input__field" value="<%= crontab_list.minute %>" />
            </div>
            <div class="finalize-form__schedule-input-field">
              <label>Hour</label>
              <input class="finalize-form-schedule-input__field" value="<%= crontab_list.hour %>" />
            </div>
            <div class="finalize-form__schedule-input-field">
              <label>Day</label>
              <input class="finalize-form-schedule-input__field" value="<%= crontab_list.day %>" />
            </div>
            <div class="finalize-form__schedule-input-field">
              <label>Month</label>
              <input class="finalize-form-schedule-input__field" value="<%= crontab_list.month %>" />
            </div>
            <div class="finalize-form__schedule-input-field">
              <label>Week</label>
              <input class="finalize-form-schedule-input__field" value="<%= crontab_list.week %>" />
            </div>
            <button class="finalize-form-cron-button cron-input-submit">Set</button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("quick_schedule", %{"schedule" => "hourly"}, socket) do
    send(self(), {:assign_crontab, "0 0 * * * *"})
    {:noreply, socket}
  end

  def handle_event("quick_schedule", %{"schedule" => "daily"}, socket) do
    send(self(), {:assign_crontab, "0 0 0 * * *"})
    {:noreply, socket}
  end

  def handle_event("quick_schedule", %{"schedule" => "weekly"}, socket) do
    send(self(), {:assign_crontab, "0 0 0 * * 0"})
    {:noreply, socket}
  end

  def handle_event("quick_schedule", %{"schedule" => "monthly"}, socket) do
    send(self(), {:assign_crontab, "0 0 0 1 * *"})
    {:noreply, socket}
  end

  def handle_event("quick_schedule", %{"schedule" => "yearly"}, socket) do
    send(self(), {:assign_crontab, "0 0 0 1 1 *"})
    {:noreply, socket}
  end

  defp parse_crontab(cron_string) do
    cron_list = String.split(cron_string)

    [:second, :minute, :hour, :day, :month, :week]
    |> Enum.zip(cron_list)
    |> Map.new()
  end
end
