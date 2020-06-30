defmodule AndiWeb.EditLiveView.FinalizeForm do
  @moduledoc """
  LiveComponent for scheduling dataset ingestion
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  alias Phoenix.HTML.Link
  alias Andi.InputSchemas.Datasets
  alias AndiWeb.ErrorHelpers

  import Crontab.CronExpression

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
    cadence_type = Map.get(assigns.scheduler_data, "cadence_type", determine_cadence_type(cadence))

    repeating_schedule = to_repeating(cadence_type, cadence)
    default_future_schedule = to_future(repeating_schedule)
    future_date = case Map.get(assigns.scheduler_data, "future_date", "") do
      "" -> default_future_schedule.date
      future_date -> future_date
    end
    future_time = case Map.get(assigns.scheduler_data, "future_time", "") do
      "" -> default_future_schedule.time
      future_time -> future_time
    end

    updated_assigns =
      assigns
      |> Map.put(:repeating_schedule, repeating_schedule)
      |> Map.put(:future_schedule, %{date: future_date, time: future_time})
      |> Map.put(:cadence_type, cadence_type)

    {:ok, assign(socket, updated_assigns)}
  end

  defp to_repeating(type, nil) when type in ["repeating", "future"], do: %{}
  defp to_repeating(type, "") when type in ["repeating", "future"], do: %{}
  defp to_repeating(type, cadence) when type in ["repeating", "future"] and cadence not in ["once", "never"], do: cronstring_to_cronlist(cadence)
  defp to_repeating(_type, cadence), do: cronstring_to_cronlist("0 * * * * *")

  defp to_future(%{year: year, month: month, day: day, hour: hour, minute: minute, second: second} = _schedule) do
    date = case Timex.parse("#{year}-#{month}-#{day}", "{YYYY}-{M}-{D}") do
      {:error, _} -> nil
      {:ok, nd} -> NaiveDateTime.to_date(nd)
    end

    time = case Timex.parse("#{hour}:#{minute}:#{second}", "{h24}:{m}:{s}") do
      {:error, _} -> nil
      {:ok, nt} -> NaiveDateTime.to_time(nt)
    end

    %{date: date, time: time}
  end
  defp to_future(%{month: _month, day: _day, hour: _hour, minute: _minute} = schedule) do
    Map.put_new(schedule, :year, current_year())
    |> Map.put_new(:second, 0)
    |> to_future()
  end
  defp to_future(_), do: {nil, nil}

  defp safe_time_new(hour, minute, second) do
    Time.new(hour, minute, second)
  rescue
    e in FunctionClauseError -> {:error, :invalid}
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
                  <%= radio_button(:scheduler, :cadence_type, "once", checked: @cadence_type == "once")%>
                  <%= label(:scheduler, :cadence_type, "Immediately", class: "finalize-form__schedule-option-label") %>
                </div>
                <div class="finalize-form__schedule-option">
                  <%= radio_button(:scheduler, :cadence_type, "future", checked: @cadence_type == "future") %>
                  <%= label(:scheduler, :cadence_type, "Future", class: "finalize-form__schedule-option-label") %>
                </div>
                <div class="finalize-form__schedule-option">
                  <%= radio_button(:scheduler, :cadence_type, "never", checked: @cadence_type == "never") %>
                  <%= label(:scheduler, :cadence_type, "Never", class: "finalize-form__schedule-option-label") %>
                </div>
                <div class="finalize-form__schedule-option">
                  <%= radio_button(:scheduler, :cadence_type, "repeating", checked: @cadence_type == "repeating") %>
                  <%= label(:scheduler, :cadence_type, "Repeating", class: "finalize-form__schedule-option-label") %>
                </div>
              </div>
              <%= hidden_input(@form, :cadence) %>
              <%= if @cadence_type == "repeating", do: repeating_scheduler_form(%{repeating_schedule: @repeating_schedule, myself: @myself}) %>
              <%= if @cadence_type == "future" do %>
                <%= future_scheduler_form(%{future_schedule: @future_schedule, myself: @myself}) %>
              <%= else %>
                <%= hidden_input(:scheduler, :future_date, value: @future_schedule.date) %>
                <%= hidden_input(:scheduler, :future_time, value: @future_schedule.time) %>
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

  defp cronstring_to_cronlist(nil), do: %{}
  defp cronstring_to_cronlist("never"), do: %{}

  defp cronstring_to_cronlist(cronstring) do
    cronlist = String.split(cronstring, " ")
    default_keys = [:minute, :hour, :day, :month, :week]

    keys =
      case crontab_length(cronstring) do
        6 -> [:second | default_keys]
        7 -> [:second] ++ default_keys ++ [:year]
        _ -> default_keys
      end

    keys
    |> Enum.zip(cronlist)
    |> Map.new()
  end

  defp to_calendar(%{day: day, month: month, year: year}) do
    case Timex.parse("#{year}-#{month}-#{day}", "{YYYY}-{M}-{D}") do
      {:ok, date} -> NaiveDateTime.to_date(date)
      _ -> nil
    end
  end
  defp to_calendar(%{day: day, month: month} = schedule) do
    to_calendar(Map.put(schedule, :year, current_year()))
  end
  defp to_calendar(_), do: nil

  defp cronlist_to_cronstring(%{second: second} = cronlist) when second != "" do
    cronlist
    |> IO.inspect(label: "what is the deal with cronlist")
    [:second, :minute, :hour, :day, :month, :week, :year]
    |> Enum.reduce("", fn field, acc ->
      acc <> " " <> to_string(Map.get(cronlist, field, "nil"))
    end)
    |> String.trim_leading()
    |> IO.inspect(label: "what is the deal with cronlist")
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

  defp future_scheduler_form(assigns) do
    ~L"""
      <div class="finalize-form__scheduler--visible">
        <div class="finalize-form__future-schedule">
          <%= label(:scheduler, :future_date, "Date of Future Ingestion") %>
          <%= date_input(:scheduler, :future_date, value: @future_schedule.date) %>
          <%= label(:scheduler, :future_time, "Time of Future Ingestion") %>
          <%= time_input(:scheduler, :future_time, value: @future_schedule.time, precision: :second, step: 15) %>
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
    new_cron = cronlist_to_cronstring(new_repeating_schedule)

    Datasets.update_cadence(socket.assigns.dataset_id, new_cron)
    send(self(), {:assign_crontab})

    {:noreply, assign(socket, repeating_schedule: new_repeating_schedule)}
  end

  def handle_event("quick_schedule", %{"schedule" => schedule}, socket) do
    cronstring = @quick_schedules[schedule]
    Datasets.update_cadence(socket.assigns.dataset_id, cronstring)
    send(self(), {:assign_crontab})

    {:noreply, assign(socket, repeating_schedule: cronstring_to_cronlist(cronstring))}
  end

  defp determine_cadence_type(nil), do: determine_cadence_type("")
  defp determine_cadence_type(cadence) when cadence in ["once", "never"], do: cadence
  defp determine_cadence_type(cadence) do
    with {:ok, parsed_cadence} <- Crontab.CronExpression.Parser.parse(cadence),
         {:error, _} <- Crontab.Scheduler.get_next_run_date(parsed_cadence) do
      "future"
    else
      _ -> "repeating"
    end
  end

  defp current_year() do
    Date.utc_today()
    |> Map.get(:year)
  end

  def update_form_with_schedule(%{"cadence_type" => cadence_type} = _sd, form_data) when cadence_type in ["once", "never"], do: put_in(form_data, ["technical", "cadence"], cadence_type)
  def update_form_with_schedule(%{"cadence_type" => "future"} = sd, form_data) do
    date = Map.get(sd, "future_date", "")
    |> IO.inspect(label: "date")
    time = Map.get(sd, "future_time", "")
    |> IO.inspect(label: "time")

    cronstring = case {date, time} do
      {"", ""} -> form_data["technical"]["cadence"]
      {date, ""} ->
        Timex.parse(date, "{YYYY}-{M}-{D}")
        |> elem(1)
        |> Map.from_struct()
        |> Map.merge(%{hour: "*", minute: "*", second: "*", week: "*"})
        |> cronlist_to_cronstring()
      {"", time} ->
        Timex.parse(time, "{h24}:{m}:{s}")
        |> elem(1)
        |> Map.from_struct()
        |> Map.merge(%{year: "*", month: "*", day: "*", week: "*"})
        |> cronlist_to_cronstring()
      {date, time} ->
        Timex.parse(date <> "T" <> time, "{YYYY}-{M}-{D}T{h24}:{m}:{s}")
        |> elem(1)
        |> Map.from_struct()
        |> Map.merge(%{week: "*"})
        |> cronlist_to_cronstring()
    end

    put_in(form_data, ["technical", "cadence"], cronstring)
  end
  def update_form_with_schedule(_sd, form_data), do: form_data
end
