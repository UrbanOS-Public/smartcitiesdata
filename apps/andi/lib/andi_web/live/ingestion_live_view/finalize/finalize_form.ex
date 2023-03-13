defmodule AndiWeb.IngestionLiveView.FinalizeForm do
  @moduledoc """
  LiveComponent for scheduling dataset ingestion
  """
  use Phoenix.LiveComponent
  use AndiWeb.FormSection, schema_module: AndiWeb.InputSchemas.FinalizeFormSchema
  import Phoenix.HTML.Form
  require Logger

  alias Andi.InputSchemas.Ingestions
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
    # new_changeset = FinalizeFormSchema.changeset_from_andi_ingestion(ingestion)
    # default_cron =
    #   case ingestion.cadence do
    #     cadence when cadence in ["once", "never", "", nil] -> "0 * * * * *"
    #     cron -> cron
    #   end

    # repeat_ingestion? = ingestion.cadence not in ["once", "never", "", nil]

    {:ok,
     assign(socket,
       visible?: false,
       repeat_ingestion?: true,
       crontab: "0 * * * * *",
       validation_status: "collapsed",
       crontab_list: parse_crontab("0 * * * * *")
     )}

    #  {:ok,
    #  assign(socket,
    #    changeset: new_changeset,
    #    repeat_ingestion?: repeat_ingestion?,
    #    crontab: default_cron,
    #    validation_status: "collapsed",
    #    crontab_list: parse_crontab(default_cron),
    #  )}
  end

  def render(assigns) do
    {_, cadence} = Changeset.fetch_field(assigns.changeset, :cadence)

    IO.inspect(assigns.changeset)
    repeat_ingestion? = cadence not in ["once", "never", "", nil]

    modifier =
      if repeat_ingestion? do
        "visible"
      else
        "hidden"
      end

    visible = if assigns.visible?, do: "expanded", else: "collapsed"

    ~L"""
    <div id="finalize_form" class="finalize-form  form-end">
      <%= live_component(
        AndiWeb.FormCollapsibleHeader,
        order: @order,
        visible?: @visible?,
        validation_status: "valid",
        step: component_step(),
        id: AndiWeb.FormCollapsibleHeader.component_id(component_step()),
        visibility_change_callback: &change_visibility/1)
      %>

      <div class="form-section">
        <%= f = form_for @changeset, "#", [phx_change: :validate, phx_target: @myself, as: :form_data] %>
          <div class="component-edit-section--<%= visible %>">
            <div class="finalize-form-edit-section form-grid">
              <div class="finalize-form__schedule">
                <fieldset style="border:none; padding-left: 0">
                  <legend><h3>Schedule Job</h3></legend>
                  <div class="finalize-form__schedule-options">
                    <div class="finalize-form__schedule-option">
                      <%= label(f, :cadence, "Immediately", class: "finalize-form__schedule-option-label", for: "form_data_cadence_once") %>
                      <%= radio_button(f, :cadence, "once")%>
                    </div>
                    <div class="finalize-form__schedule-option">
                      <%= label(f, :cadence, "Repeat", class: "finalize-form__schedule-option-label", for: "form_data_cadence_0__________") %>
                      <%= radio_button(f, :cadence, @crontab) %>
                    </div>
                  </div>
                </fieldset>

                <div class="finalize-form__scheduler--<%= modifier %>">
                <h4>Quick Schedule</h4>

                <div class="finalize-form__quick-schedule">
                  <button aria-label="Quick Schedule Hourly" type="button" class="finalize-form-cron-button" phx-target="<%= @myself %>" phx-click="quick_schedule" phx-value-schedule="hourly" >Hourly</button>
                  <button aria-label="Quick Schedule Daily" type="button" class="finalize-form-cron-button" phx-target="<%= @myself %>" phx-click="quick_schedule" phx-value-schedule="daily">Daily</button>
                  <button aria-label="Quick Schedule Weekly" type="button" class="finalize-form-cron-button" phx-target="<%= @myself %>" phx-click="quick_schedule" phx-value-schedule="weekly">Weekly</button>
                  <button aria-label="Quick Schedule Monthly" type="button" class="finalize-form-cron-button" phx-target="<%= @myself %>" phx-click="quick_schedule" phx-value-schedule="monthly">Monthly</button>
                  <button aria-label="Quick Schedule Yearly" type="button" class="finalize-form-cron-button" phx-target="<%= @myself %>" phx-click="quick_schedule" phx-value-schedule="yearly">Yearly</button>
                </div>

                <div class="finalize-form__help-link">
                  <a href="https://en.wikipedia.org/wiki/Cron" target="_blank">Cron Schedule Help</a>
                </div>

                <div class="finalize-form__schedule-input">
                  <div class="finalize-form__schedule-input-field">
                    <label for="finalize-form-schedule-input__second">Second</label>
                    <input aria-label="Cron Schedule Second" id="finalize-form-schedule-input__second" class="finalize-form-schedule-input__field" phx-target="<%= @myself %>" phx-keyup="set_schedule" phx-value-input-field="second" value="<%= @crontab_list[:second] %>" />
                  </div>
                  <div class="finalize-form__schedule-input-field">
                    <label for="finalize-form-schedule-input__minute">Minute</label>
                    <input aria-label="Cron Schedule Minute" id="finalize-form-schedule-input__minute" class="finalize-form-schedule-input__field" phx-target="<%= @myself %>" phx-keyup="set_schedule" phx-value-input-field="minute" value="<%= @crontab_list[:minute] %>" />
                  </div>
                  <div class="finalize-form__schedule-input-field">
                    <label for="finalize-form-schedule-input__hour">Hour</label>
                    <input aria-label="Cron Schedule Hour" id="finalize-form-schedule-input__hour" class="finalize-form-schedule-input__field" phx-target="<%= @myself %>" phx-keyup="set_schedule" phx-value-input-field="hour" value="<%= @crontab_list[:hour] %>" />
                  </div>
                  <div class="finalize-form__schedule-input-field">
                    <label for="finalize-form-schedule-input__day">Day</label>
                    <input aria-label="Cron Schedule Day" id="finalize-form-schedule-input__day" class="finalize-form-schedule-input__field" phx-target="<%= @myself %>" phx-keyup="set_schedule" phx-value-input-field="day" value="<%= @crontab_list[:day] %>" />
                  </div>
                  <div class="finalize-form__schedule-input-field">
                    <label for="finalize-form-schedule-input__month">Month</label>
                    <input aria-label="Cron Schedule Month" id="finalize-form-schedule-input__month" class="finalize-form-schedule-input__field" phx-target="<%= @myself %>" phx-keyup="set_schedule" phx-value-input-field="month" value="<%= @crontab_list[:month] %>" />
                  </div>
                  <div class="finalize-form__schedule-input-field">
                    <label for="finalize-form-schedule-input__week">Week</label>
                    <input aria-label="Cron Schedule Week" id="finalize-form-schedule-input__week" class="finalize-form-schedule-input__field" phx-target="<%= @myself %>" phx-keyup="set_schedule" phx-value-input-field="week" value="<%= @crontab_list[:week] %>" />
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

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    finalize_form_changeset = FinalizeFormSchema.changeset(socket.assigns.changeset, form_data)
    send(self(), {:updated_finalize, finalize_form_changeset})
    {:noreply, socket}
  end

  def handle_event("publish", _, socket) do
    send(socket.parent_pid, :publish)

    {:noreply, socket}
  end

  def handle_event("set_schedule", %{"input-field" => input_field, "value" => value}, socket) do
    new_crontab_list = Map.put(socket.assigns.crontab_list, String.to_existing_atom(input_field), value)

    new_cron = cronlist_to_cronstring(new_crontab_list)

    {:ok, andi_ingestion} = Ingestions.update_cadence(socket.assigns.ingestion_id, new_cron)

    {_, updated_socket} =
      andi_ingestion
      |> FinalizeFormSchema.changeset_from_andi_ingestion()
      |> complete_validation(socket)

    {:noreply, assign(updated_socket, crontab: new_cron, crontab_list: new_crontab_list)}
  end

  def handle_event("quick_schedule", %{"schedule" => schedule}, socket) do
    cronstring = @quick_schedules[schedule]

    {:ok, andi_ingestion} = Ingestions.update_cadence(socket.assigns.ingestion_id, cronstring)

    {_, updated_socket} =
      andi_ingestion
      |> FinalizeFormSchema.changeset_from_andi_ingestion()
      |> complete_validation(socket)

    {:noreply, assign(updated_socket, crontab: cronstring, crontab_list: parse_crontab(cronstring))}
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

  defp complete_validation(changeset, socket) do
    new_changeset = Map.put(changeset, :action, :update)
    cadence = Ecto.Changeset.get_field(changeset, :cadence)

    if cadence == "once" do
      Ingestions.update_cadence(socket.assigns.ingestion_id, cadence)
    end

    repeat_ingestion? = cadence not in ["once", "never", nil]
    send(socket.parent_pid, :form_update)

    {:noreply,
     assign(socket, changeset: new_changeset, repeat_ingestion?: repeat_ingestion?)
     |> update_validation_status()}
  end
end
