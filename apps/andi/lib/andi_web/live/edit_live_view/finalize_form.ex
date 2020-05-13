defmodule AndiWeb.EditLiveView.FinalizeForm do
  @moduledoc """
  LiveComponent for scheduling dataset ingestion
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  alias Andi.InputSchemas.Datasets
  alias Crontab.CronExpression

  @quick_schedules %{
    "hourly" => "0 0 * * * *",
    "daily" => "0 0 0 * * *",
    "weekly" => "0 0 0 * * 0",
    "monthly" => "0 0 0 1 * *",
    "yearly" => "0 0 0 1 1 *"
  }

  def mount(socket) do
    {:ok, assign(socket, error_msg: "")}
  end

  def update(assigns, socket) do
    crontab = Map.get(assigns, :crontab, input_value(assigns.form, :cadence))
    repeat_ingestion? = input_value(assigns.form, :cadence) not in ["once", "never"]

    updated_assigns =
      assigns
      |> Map.put_new(:crontab_list, parse_crontab(crontab))
      |> Map.put(:repeat_ingestion?, repeat_ingestion?)
      |> Map.put(:error_msg, "")

    {:ok, assign(socket, updated_assigns)}
  end

  def render(assigns) do
    modifier =
      if assigns.repeat_ingestion? do
        "visible"
      else
        "hidden"
      end

    has_error_msg =
      if assigns.error_msg != "" do
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

          <p class="error-msg finalize-form__error-msg--<%= has_error_msg %>"><%= @error_msg %></p>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("set_schedule", _, socket) do
    new_cron =
      socket.assigns.crontab_list
      |> cronlist_to_cronstring()

    case CronExpression.Parser.parse(new_cron, true) do
      {:ok, _} ->
        Datasets.update_cadence(socket.assigns.dataset_id, new_cron)
        send(self(), {:assign_crontab, new_cron})
        {:noreply, assign(socket, error_msg: "")}

      {:error, error_msg} ->
        {:noreply, assign(socket, error_msg: error_msg)}
    end
  end

  def handle_event("quick_schedule", %{"schedule" => schedule}, socket) do
    cronstring = @quick_schedules[schedule]
    Datasets.update_cadence(socket.assigns.dataset_id, cronstring)
    send(self(), {:assign_crontab, cronstring})

    {:noreply, socket}
  end

  def handle_event("update_cron", %{"input-field" => input_field, "value" => value}, socket) do
    new_crontab = Map.put(socket.assigns.crontab_list, String.to_atom(input_field), value)
    {:noreply, assign(socket, crontab_list: new_crontab)}
  end

  defp parse_crontab(nil), do: %{}
  defp parse_crontab("never"), do: %{}

  defp parse_crontab(cronstring) do
    cronlist = String.split(cronstring)
    default_keys = [:minute, :hour, :day, :month, :week]

    keys =
      case crontab_length(cronstring) do
        6 -> [:second | default_keys]
        _ -> default_keys
      end

    keys
    |> Enum.zip(cronlist)
    |> Map.new()
  end

  defp cronlist_to_cronstring(%{second: _} = cronlist) do
    [:second, :minute, :hour, :day, :month, :week]
    |> Enum.reduce("", fn field, acc ->
      acc <> " " <> Map.get(cronlist, field, "nil")
    end)
    |> String.trim_leading()
  end

  defp cronlist_to_cronstring(cronlist) do
    cronlist
    |> Map.put(:second, "0")
    |> cronlist_to_cronstring()
  end

  defp crontab_length(cronstring) do
    cronstring
    |> String.split()
    |> Enum.count()
  end
end
