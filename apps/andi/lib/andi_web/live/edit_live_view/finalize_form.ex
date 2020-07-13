defmodule AndiWeb.EditLiveView.FinalizeForm do
  @moduledoc """
  LiveComponent for scheduling dataset ingestion
  """
  use Phoenix.LiveView
  import Phoenix.HTML.Form
  require Logger

  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.InputConverter
  alias AndiWeb.InputSchemas.FinalizeFormSchema
  alias AndiWeb.ErrorHelpers

  @quick_schedules %{
    "hourly" => "0 0 * * * *",
    "daily" => "0 0 0 * * *",
    "weekly" => "0 0 0 * * 0",
    "monthly" => "0 0 0 1 * *",
    "yearly" => "0 0 0 1 1 *"
  }

  def mount(_, %{"dataset" => dataset}, socket) do
    new_changeset = FinalizeFormSchema.changeset_from_andi_dataset(dataset)
    AndiWeb.Endpoint.subscribe("toggle-visibility")

    default_cron =
      case dataset.technical.cadence do
        cadence when cadence in ["once", "never", "", nil] -> "0 * * * * *"
        cron -> cron
      end

    repeat_ingestion? = dataset.technical.cadence not in ["once", "never", "", nil]

    {:ok, assign(socket,
        visibility: "collapsed",
        changeset: new_changeset,
        repeat_ingestion?: repeat_ingestion?,
        crontab: default_cron,
        validation_status: "collapsed",
        crontab_list: parse_crontab(default_cron),
        dataset_id: dataset.id
      )}
  end

  def render(assigns) do
    modifier =
      if assigns.repeat_ingestion? do
        "visible"
      else
        "hidden"
      end

    action =
      case assigns.visibility do
        "collapsed" -> "EDIT"
        "expanded" -> "MINIMIZE"
      end

    ~L"""
    <div id="finalize_form" class="finalize-form finalize-form--<%= @visibility %>">
      <div class="component-header" phx-click="toggle-component-visibility" phx-value-component="finalize_form">
        <div class="section-number">
          <h3 class="component-number component-number--<%= @validation_status %>">4</h3>
          <div class="component-number-status--<%= @validation_status %>"></div>
        </div>
        <div class="component-title full-width">
          <h2 class="component-title-text component-title-text--<%= @visibility %> ">Finalize</h2>
          <div class="component-title-action">
            <div class="component-title-action-text--<%= @visibility %>"><%= action %></div>
            <div class="component-title-icon--<%= @visibility %>"></div>
          </div>
        </div>
      </div>

      <div class="form-section">
        <%= f = form_for @changeset, "#", [phx_change: :cam, as: :form_data] %>
          <div class="component-edit-section--<%= @visibility %>">
            <div class="finalize-form-edit-section form-grid">
              <div "finalize-form__schedule">
                <h3>Schedule Job</h3>

                <div class="finalize-form__schedule-options">
                  <div class="finalize-form__schedule-option">
                    <%= label(f, :cadence, "Immediately", class: "finalize-form__schedule-option-label") %>
                    <%= radio_button(f, :cadence, "once")%>
                  </div>
                  <div class="finalize-form__schedule-option">
                  <%= label(f, :cadence, "Never", class: "finalize-form__schedule-option-label") %>
                  <%= radio_button(f, :cadence, "never") %>
                  </div>
                  <div class="finalize-form__schedule-option">
                    <%= label(f, :cadence, "Repeat", class: "finalize-form__schedule-option-label") %>
                    <%= radio_button(f, :cadence, @crontab) %>
                  </div>
                </div>

                <div class="finalize-form__scheduler--<%= modifier %>">
                  <h4>Quick Schedule</h4>

                  <div class="finalize-form__quick-schedule">
                    <button type="button" class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="hourly" >Hourly</button>
                    <button type="button" class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="daily">Daily</button>
                    <button type="button" class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="weekly">Weekly</button>
                    <button type="button" class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="monthly">Monthly</button>
                    <button type="button" class="finalize-form-cron-button" phx-click="quick_schedule" phx-value-schedule="yearly">Yearly</button>
                  </div>

                  <div class="finalize-form__help-link">
                    <a href="https://en.wikipedia.org/wiki/Cron" target="_blank">Cron Schedule Help</a>
                  </div>

                  <div class="finalize-form__schedule-input">
                    <div class="finalize-form__schedule-input-field">
                      <label>Second</label>
                      <input class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-value-input-field="second" value="<%= @crontab_list[:second] %>" />

                    </div>
                    <div class="finalize-form__schedule-input-field">
                      <label>Minute</label>
                      <input class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-value-input-field="minute" value="<%= @crontab_list[:minute] %>" />
                    </div>
                    <div class="finalize-form__schedule-input-field">
                      <label>Hour</label>
                      <input class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-value-input-field="hour" value="<%= @crontab_list[:hour] %>" />
                    </div>
                    <div class="finalize-form__schedule-input-field">
                      <label>Day</label>
                      <input class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-value-input-field="day" value="<%= @crontab_list[:day] %>" />
                    </div>
                    <div class="finalize-form__schedule-input-field">
                      <label>Month</label>
                      <input class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-value-input-field="month" value="<%= @crontab_list[:month] %>" />
                    </div>
                    <div class="finalize-form__schedule-input-field">
                      <label>Week</label>
                      <input class="finalize-form-schedule-input__field" phx-keyup="set_schedule" phx-value-input-field="week" value="<%= @crontab_list[:week] %>" />
                    </div>
                  </div>
                </div>
                <%= ErrorHelpers.error_tag(f, :cadence) %>
              </div>
            </div>

            <div class="edit-button-group form-grid">
              <div class="edit-button-group__cancel-btn">
                <a href="#url-form" id="back-button" class="btn btn--back btn--large" phx-click="toggle-component-visibility" phx-value-component-expand="url_form">Back</a>
                <button type="button" class="btn btn--large" phx-click="cancel-edit">Cancel</button>
              </div>

              <div class="edit-button-group__save-btn">
                <button type="button" id="publish-button" class="btn btn--publish btn--action btn--large" phx-click="publish">Publish</button>
                <button id="save-button" name="save-button" class="btn btn--save btn--large" type="button" phx-click="camsave">Save Draft</button>
              </div>
            </div>
          </div>
        </form>
      </div>
    </div>
    """
  end

  def handle_event("cam", %{"form_data" => form_data}, socket) do
    form_data
    |> FinalizeFormSchema.changeset_from_form_data()
    |> complete_validation(socket)
  end

  def handle_event("camsave", _, socket) do
    changeset =
      socket.assigns.changeset
      |> Map.put(:action, :update)

    send(socket.parent_pid, {:form_save, changeset})

    new_validation_status = case changeset.valid? do
                              true -> "valid"
                              false -> "invalid"
                            end

    {:noreply, assign(socket, changeset: changeset, validation_status: new_validation_status)}
  end

  def handle_event("publish", _, socket) do
    changeset =
      socket.assigns.changeset
      |> Map.put(:action, :update)

    changes = Ecto.Changeset.apply_changes(changeset) |> StructTools.to_map
    {:ok, andi_dataset} = Datasets.update_from_form(socket.assigns.dataset_id, changes)
    dataset_changeset = InputConverter.andi_dataset_to_full_ui_changeset(andi_dataset)

    if dataset_changeset.valid? do
      {:ok, smrt_dataset} = InputConverter.andi_dataset_to_smrt_dataset(andi_dataset)

      # case Brook.Event.send(instance_name(), dataset_update(), :andi, smrt_dataset) do
      case :ok do
        :ok ->
          send(socket.parent_pid, {:publish_succeeded, dataset: andi_dataset, changeset: dataset_changeset})

        error ->
          Logger.warn("Unable to create new SmartCity.Dataset: #{inspect(error)}")
      end
    else
      send(socket.parent_pid, {:publish_failed, changeset: %{dataset_changeset | action: :save}})
    end

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("toggle-component-visibility", %{"component-expand" => next_component}, socket) do
    new_validation_status = case socket.assigns.changeset.valid? do
                              true -> "valid"
                              false -> "invalid"
                            end

    AndiWeb.Endpoint.broadcast_from(self(), "toggle-visibility", "toggle-component-visibility", %{expand: next_component})

    {:noreply, assign(socket, visibility: "collapsed", validation_status: new_validation_status)}
  end

  def handle_event("toggle-component-visibility", _, socket) do
    current_visibility = Map.get(socket.assigns, :visibility)

    new_visibility = case current_visibility do
                       "expanded" -> "collapsed"
                       "collapsed" -> "expanded"
                     end

    {:noreply, assign(socket, visibility: new_visibility) |> update_validation_status()}
  end

  defp update_validation_status(%{assigns: %{validation_status: validation_status}} = socket) when validation_status in ["valid", "invalid"] do
    new_status = case socket.assigns.changeset.valid? do
                   true -> "valid"
                   false -> "invalid"
                 end

    assign(socket, validation_status: new_status)
  end

  def handle_event("set_schedule", %{"input-field" => input_field, "value" => value}, socket) do
    new_crontab_list = Map.put(socket.assigns.crontab_list, String.to_existing_atom(input_field), value)
    new_cron = cronlist_to_cronstring(new_crontab_list)

    {:ok, andi_dataset} = Datasets.update_cadence(socket.assigns.dataset_id, new_cron)

    {_, updated_socket} =
      andi_dataset
      |> FinalizeFormSchema.changeset_from_andi_dataset()
      |> complete_validation(socket)

    {:noreply, assign(updated_socket, crontab: new_cron, crontab_list: new_crontab_list)}
  end

  def handle_event("quick_schedule", %{"schedule" => schedule}, socket) do
    cronstring = @quick_schedules[schedule]
    {:ok, andi_dataset} = Datasets.update_cadence(socket.assigns.dataset_id, cronstring)

    {_, updated_socket} =
      andi_dataset
      |> FinalizeFormSchema.changeset_from_andi_dataset()
      |> complete_validation(socket)

    {:noreply, assign(updated_socket, crontab: cronstring, crontab_list: parse_crontab(cronstring))}
  end

  def handle_event("cancel-edit", _, socket) do
    send(socket.parent_pid, :cancel_edit)
    {:noreply, socket}
  end

  def handle_info(%{topic: "toggle-visibility", payload: %{expand: "finalize_form"}}, socket) do
    {:noreply, assign(socket, visibility: "expanded") |> update_validation_status()}
  end

  def handle_info(%{topic: "toggle-visibility", payload: _}, socket) do
    {:noreply, socket}
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
    repeat_ingestion? = cadence not in ["once", "never", nil]
    send(socket.parent_pid, :form_update)

    {:noreply, assign(socket, changeset: new_changeset, repeat_ingestion?: repeat_ingestion?) |> update_validation_status()}
  end

  defp update_validation_status(%{assigns: %{visibility: visibility}} = socket), do: assign(socket, validation_status: visibility)
end
