defmodule AndiWeb.ExtractSteps.ExtractHttpStepForm do
  @moduledoc """
  LiveComponent for an extract step with type HTTP
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML
  import Phoenix.HTML.Form

  alias Andi.InputSchemas.Datasets.ExtractHttpStep
  alias AndiWeb.EditLiveView.KeyValueEditor
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.Options
  alias AndiWeb.Views.DisplayNames
  alias Andi.InputSchemas.StructTools
  alias AndiWeb.Views.HttpStatusDescriptions
  alias Andi.InputSchemas.ExtractHttpSteps
  alias AndiWeb.Helpers.FormTools

  def render(assigns) do
    ~L"""
        <div class="form-section extract-step-container">
          <%= f = form_for @changeset, "#", [phx_change: :validate, as: :form_data] %>
            <%= hidden_input(f, :id) %>
            <%= hidden_input(f, :type) %>
            <%= hidden_input(f, :technical_id) %>

            <div class="component-edit-section--<%= @visibility %>">
              <div class="extract-step-form-edit-section form-grid">
                <div class="extract-step-form__type">
                  <%= label(f, :type, DisplayNames.get(:type), class: "label") %>
                  <%= select(f, :type, get_extract_step_types(), id: "step_type", class: "extract-step-form__type select") %>
                </div>

                <div class="extract-step-form__method">
                  <%= label(f, :method, DisplayNames.get(:method), class: "label label--required") %>
                  <%= select(f, :method, get_http_methods(), id: "http_method", class: "extract-step-form__method select") %>
                  <%= ErrorHelpers.error_tag(f, :type) %>
                </div>

                <div class="extract-step-form__url">
                  <%= label(f, :url, DisplayNames.get(:url), class: "label label--required") %>
                  <%= text_input(f, :url, class: "input full-width", disabled: @testing) %>
                  <%= ErrorHelpers.error_tag(f, :url, bind_to_input: false) %>
                </div>

                <%= live_component(@socket, KeyValueEditor, id: :key_value_editor_queryParams, css_label: "source-query-params", form: f, field: :queryParams ) %>

                <%= live_component(@socket, KeyValueEditor, id: :key_value_editor_headers, css_label: "source-headers", form: f, field: :headers ) %>

                <%= if input_value(f, :method) == "POST" do %>
                  <div class="extract-step-form__body">
                    <%= label(f, :body, DisplayNames.get(:body), class: "label") %>
                    <%= textarea(f, :body, class: "input full-width", disabled: @testing) %>
                    <%= ErrorHelpers.error_tag(f, :body) %>
                  </div>
                <% end %>

                <div class="extract-step-form__test-section">
                  <button type="button" class="extract_step__test-btn btn--test btn btn--large btn--action" phx-click="test_url" <%= disabled?(@testing) %>>Test</button>
                  <%= if @test_results do %>
                    <div class="test-status">
                    Status: <span class="test-status__code <%= status_class(@test_results) %>"><%= @test_results |> Map.get(:status) |> HttpStatusDescriptions.simple() %></span>
                    <%= status_tooltip(@test_results) %>
                    Time: <span class="test-status__time"><%= @test_results |> Map.get(:time) %></span> ms
                    </div>
                  <% end %>
                </div>
              </div>

              <div class="edit-button-group form-grid">
                <div class="edit-button-group__cancel-btn">
                  <a href="#data-dictionary-form" id="back-button" class="btn btn--back btn--large" phx-click="toggle-component-visibility" phx-value-component-expand="data_dictionary_form">Back</a>
                  <button type="button" class="btn btn--large" phx-click="cancel-edit">Cancel</button>
                </div>

                <div class="edit-button-group__save-btn">
                  <a href="#finalize_form" id="next-button" class="btn btn--next btn--large btn--action" phx-click="toggle-component-visibility" phx-value-component-expand="finalize_form">Next</a>
                  <button id="save-button" name="save-button" class="btn btn--save btn--large" type="button" phx-click="save">Save Draft</button>
                </div>
                </div>
            </div>
          </form>
        </div>
    """
  end

  defp disabled?(true), do: "disabled"
  defp disabled?(_), do: ""

  defp status_class(%{status: status}) when status in 200..399, do: "test-status__code--good"
  defp status_class(%{status: _}), do: "test-status__code--bad"
  defp status_tooltip(%{status: status}) when status in 200..399, do: status_tooltip(%{status: status}, "shown")

  defp status_tooltip(%{status: status}, modifier \\ "shown") do
    assigns = %{
      description: HttpStatusDescriptions.get(status),
      modifier: modifier
    }

    ~E(<sup class="test-status__tooltip-wrapper"><i phx-hook="addTooltip" data-tooltip-content="<%= @description %>" class="material-icons-outlined test-status__tooltip--<%= @modifier %>">info</i></sup>)
  end

  defp key_values_to_keyword_list(form_data, field) do
    form_data
    |> Map.get(field, [])
    |> Enum.map(fn %{key: key, value: value} -> {key, value} end)
  end

  defp get_extract_step_types(), do: map_to_dropdown_options(Options.extract_step_type())
  defp get_http_methods(), do: map_to_dropdown_options(Options.http_method())

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} -> [key: description, value: actual_value] end)
  end

  defp save_draft(socket) do
    new_validation_status =
      case socket.assigns.changeset.valid? do
        true -> "valid"
        false -> "invalid"
      end

    new_changes =
      socket.assigns.changeset
      |> Andi.InputSchemas.InputConverter.form_changes_from_changeset()

    Andi.InputSchemas.Datasets.update_from_form(socket.assigns.dataset_id, %{extractSteps: [new_changes]})

    {:noreply, assign(socket, validation_status: new_validation_status)}
  end

  defp update_validation_status(%{assigns: %{validation_status: validation_status, visibility: visibility}} = socket)
       when validation_status in ["valid", "invalid"] or visibility == "collapsed" do
    assign(socket, validation_status: get_new_validation_status(socket.assigns.changeset))
  end

  defp update_validation_status(%{assigns: %{visibility: visibility}} = socket), do: assign(socket, validation_status: visibility)

  defp get_new_validation_status(changeset) do
    case changeset.valid? do
      true -> "valid"
      false -> "invalid"
    end
  end
end
