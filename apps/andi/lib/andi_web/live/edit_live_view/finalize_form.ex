defmodule AndiWeb.EditLiveView.FinalizeForm do
  @moduledoc """
  LiveComponent for scheduling dataset ingestion
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  alias Andi.InputSchemas.Datasets

  def mount(socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    repeat_ingestion? = input_value(assigns.form, :cadence) != "once"
    crontab_list = parse_crontab(assigns.crontab)

    updated_assigns =
      assigns
      |> Map.put(:crontab_list, crontab_list)
      |> Map.put(:repeat_ingestion?, repeat_ingestion?)

    {:ok, assign(socket, updated_assigns)}
  end

  def render(assigns) do
    modifier =
      if assigns.repeat_ingestion? do
        "visible"
      else
        "hidden"
      end

    ~L"""
    <div id="<%= @id %>">
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
            <button type="button" class="finalize-form-cron-button">Startup</button>
            <button type="button" class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="hourly" phx-target="<%= @myself %>">Hourly</button>
            <button type="button" class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="daily" phx-target="<%= @myself %>">Daily</button>
            <button type="button" class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="weekly" phx-target="<%= @myself %>">Weekly</button>
            <button type="button" class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="monthly" phx-target="<%= @myself %>">Monthly</button>
            <button type="button" class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="yearly" phx-target="<%= @myself %>">Yearly</button>
          </div>

          <div class="finalize-form__schedule-input">
            <div class="finalize-form__schedule-input-field">
              <label>Second</label>
              <input class="finalize-form-schedule-input__field" phx-keyup="update_cron" phx-value-input-field="second" phx-target="<%= @myself %>" value="<%= @crontab_list[:second] %>" />

            </div>
            <div class="finalize-form__schedule-input-field">
              <label>Minute</label>
              <input class="finalize-form-schedule-input__field" phx-keyup="update_cron" phx-value-input-field="minute" phx-target="<%= @myself %>" value="<%= @crontab_list[:minute] %>" />
            </div>
            <div class="finalize-form__schedule-input-field">
              <label>Hour</label>
              <input class="finalize-form-schedule-input__field" phx-keyup="update_cron" phx-value-input-field="hour" phx-target="<%= @myself %>" value="<%= @crontab_list[:hour] %>" />
            </div>
            <div class="finalize-form__schedule-input-field">
              <label>Day</label>
              <input class="finalize-form-schedule-input__field" phx-keyup="update_cron" phx-value-input-field="day" phx-target="<%= @myself %>" value="<%= @crontab_list[:day] %>" />
            </div>
            <div class="finalize-form__schedule-input-field">
              <label>Month</label>
              <input class="finalize-form-schedule-input__field" phx-keyup="update_cron" phx-value-input-field="month" phx-target="<%= @myself %>" value="<%= @crontab_list[:month] %>" />
            </div>
            <div class="finalize-form__schedule-input-field">
              <label>Week</label>
              <input class="finalize-form-schedule-input__field" phx-keyup="update_cron" phx-value-input-field="week" phx-target="<%= @myself %>" value="<%= @crontab_list[:week] %>" />
            </div>
            <button type="button" class="finalize-form-cron-button cron-input-submit" phx-click="set_schedule" phx-target="<%= @myself %>">Set</button>
          </div>

        </div>
      </div>
    </div>
    """
  end

  def handle_event("set_schedule", _, socket) do
    new_cron = socket.assigns.crontab_list
    |> cronlist_to_cronstring()

    Datasets.update_cadence(socket.assigns.dataset_id, new_cron)
    send(self(), {:assign_crontab, new_cron})

    {:noreply, socket}
  end

  def handle_event("quick_schedule", %{"schedule" => "hourly"}, socket) do
    Datasets.update_cadence(socket.assigns.dataset_id, "0 0 * * * *")
    send(self(), {:assign_crontab, "0 0 * * * *"})

    {:noreply, socket}
  end

  def handle_event("quick_schedule", %{"schedule" => "daily"}, socket) do
    Datasets.update_cadence(socket.assigns.dataset_id, "0 0 0 * * *")
    send(self(), {:assign_crontab, "0 0 0 * * *"})

    {:noreply, socket}
  end

  def handle_event("quick_schedule", %{"schedule" => "weekly"}, socket) do
    Datasets.update_cadence(socket.assigns.dataset_id, "0 0 0 * * 0")
    send(self(), {:assign_crontab, "0 0 0 * * 0"})
    {:noreply, socket}
  end

  def handle_event("quick_schedule", %{"schedule" => "monthly"}, socket) do
    Datasets.update_cadence(socket.assigns.dataset_id, "0 0 0 1 * *")
    send(self(), {:assign_crontab, "0 0 0 1 * *"})
    {:noreply, socket}
  end

  def handle_event("quick_schedule", %{"schedule" => "yearly"}, socket) do
    Datasets.update_cadence(socket.assigns.dataset_id, "0 0 0 1 1 *")
    send(self(), {:assign_crontab, "0 0 0 1 1 *"})
    {:noreply, socket}
  end


  def handle_event("update_cron", %{"input-field" => input_field, "value" => value}, socket) do
    new_crontab = Map.put(socket.assigns.crontab_list, String.to_atom(input_field), value)
    {:noreply, assign(socket, crontab_list: new_crontab)}
  end

  defp parse_crontab(cron_string) when byte_size(cron_string) == 11 do
    cron_list = String.split(cron_string)

    [:second, :minute, :hour, :day, :month, :week]
    |> Enum.zip(cron_list)
    |> Map.new()
  end

  defp parse_crontab(cron_string) do
    cron_list = String.split(cron_string)

    [:minute, :hour, :day, :month, :week]
    |> Enum.zip(cron_list)
    |> Map.new()
  end

  defp cronlist_to_cronstring(cronlist) when map_size(cronlist) == 6 do
    [:minute, :hour, :day, :month, :week]
    |> Enum.reduce(cronlist.second, fn field, acc ->
      acc <> " " <> cronlist[field]
    end)
  end

  defp cronlist_to_cronstring(cronlist) do
    [:hour, :day, :month, :week]
    |> Enum.reduce(cronlist.minute, fn field, acc ->
      acc <> " " <> cronlist[field]
    end)
  end
end
