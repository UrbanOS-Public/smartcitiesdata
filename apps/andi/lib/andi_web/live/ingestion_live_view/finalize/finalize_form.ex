defmodule AndiWeb.IngestionLiveView.FinalizeForm do
  @moduledoc """
  LiveComponent for scheduling dataset ingestion
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  require Logger

  alias AndiWeb.InputSchemas.FinalizeFormSchema
  alias AndiWeb.ErrorHelpers
  alias Ecto.Changeset

  @quick_schedules %{
    "hourly" => "0 0 * * * *",
    "daily" => "0 0 0 * * *",
    "weekly" => "0 0 0 * * 0",
    "monthly" => "0 0 0 1 * *",
    "yearly" => "0 0 0 1 1 *"
  }
  def component_id() do
    :finalize_form_editor
  end

  def component_step(), do: "Finalize"

  def mount(socket) do
    {:ok,
     assign(socket,
       visible?: false,
       repeat_ingestion?: true,
       validation_status: "collapsed"
     )}
  end

  def render(assigns) do
    {_, cadence} = Changeset.fetch_field(assigns.changeset, :cadence)

    repeat_ingestion? = cadence not in ["once", "never", "", nil]

    modifier =
      if repeat_ingestion? do
        "visible"
      else
        "hidden"
      end

    visible = if assigns.visible?, do: "expanded", else: "collapsed"

    validation_status = if assigns.changeset.valid?, do: "valid", else: "invalid"

    cron_string = build_cron_string(cadence)
    crontab_list = parse_crontab(cron_string)

    ~L"""
    <div id="finalize_component" class="finalize-form form-end">
      <%= live_component(
        AndiWeb.FormCollapsibleHeader,
        order: @order,
        visible?: @visible?,
        validation_status: validation_status,
        step: component_step(),
        id: AndiWeb.FormCollapsibleHeader.component_id(component_step()),
        visibility_change_callback: &change_visibility/1)
      %>

      <div class="form-section">
        <%= f = form_for @changeset, "#", [phx_change: :update, phx_target: @myself, as: :form_data, id: :finalize_form] %>
          <div class="component-edit-section--<%= visible %>">
            <div class="finalize-form-edit-section form-grid">
              <div class="finalize-form__schedule">
                <fieldset style="border:none; padding-left: 0">
                  <legend><h3>Schedule Job</h3></legend>
                  <div class="finalize-form__schedule-options">
                    <div class="finalize-form__schedule-option">
                      <%= label(f, :cadence, "Immediately", class: "finalize-form__schedule-option-label", for: "finalize_form_cadence_once") %>
                      <%= radio_button(f, :cadence, "once")%>
                    </div>
                    <div class="finalize-form__schedule-option">
                      <%= label(f, :cadence, "Repeat", class: "finalize-form__schedule-option-label", for: "finalize_form_cadence_0__________") %>
                      <%= radio_button(f, :cadence, cron_string) %>
                    </div>
                  </div>
                </fieldset>

                <div class="finalize-form__scheduler--<%= modifier %>">
                <h4>Quick Schedule</h4>

                <div class="finalize-form__quick-schedule">
                  <button aria-label="Quick Schedule Hourly" type="button" id="quick_schedule_hourly" class="finalize-form-cron-button" phx-target="<%= @myself %>" phx-click="quick_schedule" phx-value-schedule="hourly" >Hourly</button>
                  <button aria-label="Quick Schedule Daily" type="button" id="quick_schedule_daily" class="finalize-form-cron-button" phx-target="<%= @myself %>" phx-click="quick_schedule" phx-value-schedule="daily">Daily</button>
                  <button aria-label="Quick Schedule Weekly" type="button" id="quick_schedule_weekly" class="finalize-form-cron-button" phx-target="<%= @myself %>" phx-click="quick_schedule" phx-value-schedule="weekly">Weekly</button>
                  <button aria-label="Quick Schedule Monthly" type="button" id="quick_schedule_monthly" class="finalize-form-cron-button" phx-target="<%= @myself %>" phx-click="quick_schedule" phx-value-schedule="monthly">Monthly</button>
                  <button aria-label="Quick Schedule Yearly" type="button" id="quick_schedule_yearly" class="finalize-form-cron-button" phx-target="<%= @myself %>" phx-click="quick_schedule" phx-value-schedule="yearly">Yearly</button>
                </div>

                <div class="finalize-form__help-link">
                  <a href="https://en.wikipedia.org/wiki/Cron" target="_blank">Cron Schedule Help</a>
                </div>

                <div class="finalize-form__schedule-input">
                  <div class="finalize-form__schedule-input-field">
                    <label for="finalize-form-schedule-input__second">Second</label>
                    <input aria-label="Cron Schedule Second" id="finalize-form-schedule-input__second" class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-target="<%= @myself %>" phx-value-input-field="second" value="<%= crontab_list[:second] %>" />
                  </div>
                  <div class="finalize-form__schedule-input-field">
                    <label for="finalize-form-schedule-input__minute">Minute</label>
                    <input aria-label="Cron Schedule Minute" id="finalize-form-schedule-input__minute" class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-target="<%= @myself %>" phx-value-input-field="minute" value="<%= crontab_list[:minute] %>" />
                  </div>
                  <div class="finalize-form__schedule-input-field">
                    <label for="finalize-form-schedule-input__hour">Hour</label>
                    <input aria-label="Cron Schedule Hour" id="finalize-form-schedule-input__hour" class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-target="<%= @myself %>" phx-value-input-field="hour" value="<%= crontab_list[:hour] %>" />
                  </div>
                  <div class="finalize-form__schedule-input-field">
                    <label for="finalize-form-schedule-input__day">Day</label>
                    <input aria-label="Cron Schedule Day" id="finalize-form-schedule-input__day" class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-target="<%= @myself %>" phx-value-input-field="day" value="<%= crontab_list[:day] %>" />
                  </div>
                  <div class="finalize-form__schedule-input-field">
                    <label for="finalize-form-schedule-input__month">Month</label>
                    <input aria-label="Cron Schedule Month" id="finalize-form-schedule-input__month" class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-target="<%= @myself %>" phx-value-input-field="month" value="<%= crontab_list[:month] %>" />
                  </div>
                  <div class="finalize-form__schedule-input-field">
                    <label for="finalize-form-schedule-input__week">Week</label>
                    <input aria-label="Cron Schedule Week" id="finalize-form-schedule-input__week" class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-target="<%= @myself %>" phx-value-input-field="week" value="<%= crontab_list[:week] %>" />
                  </div>
                </div>
              </div>
              <%= ErrorHelpers.error_tag(f, :cadence) %>
              </div>
            </div>
          </div>
        </form>
      </div>

    </div>
    """
  end

  def handle_event(
        "set_schedule",
        %{"input-field" => input_field, "value" => value},
        socket
      ) do
    {_, cadence} = Changeset.fetch_field(socket.assigns.changeset, :cadence)

    new_cron =
      cadence
      |> build_cron_string()
      |> parse_crontab()
      |> Map.put(String.to_existing_atom(input_field), value)
      |> cronlist_to_cronstring()

    form_data = %{"cadence" => new_cron}

    update_ingestion(socket, form_data)
  end

  def handle_event("update", %{"form_data" => form_data}, socket) do
    update_ingestion(socket, form_data)
  end

  def handle_event("update", _, socket) do
    {:noreply, socket}
  end

  def handle_event("publish", _, socket) do
    send(socket.parent_pid, :publish)

    {:noreply, socket}
  end

  def handle_event("quick_schedule", %{"schedule" => schedule}, socket) do
    cronstring = @quick_schedules[schedule]
    form_data = %{"cadence" => cronstring}

    update_ingestion(socket, form_data)
  end

  def handle_info(%{topic: "toggle-visibility"}, socket) do
    {:noreply, socket}
  end

  def change_visibility(updated_visibility) do
    send_update(__MODULE__,
      id: component_id(),
      visible?: updated_visibility
    )
  end

  defp parse_crontab(nil), do: %{}
  defp parse_crontab("never"), do: %{}

  defp parse_crontab(cronstring) do
    cronlist = String.split(cronstring, " ")
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

  defp update_ingestion(socket, form_data) do
    finalize_form_changeset = FinalizeFormSchema.changeset(socket.assigns.changeset, form_data)
    send(self(), {:updated_finalize, finalize_form_changeset})
    {:noreply, socket}
  end

  defp cronlist_to_cronstring(%{second: second} = cronlist) when second != "" do
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
    |> String.split(" ")
    |> Enum.count()
  end

  defp build_cron_string(cadence) do
    case cadence do
      cadence when cadence in ["once", "never", "", nil] -> "0 * * * * *"
      cron -> cron
    end
  end
end
