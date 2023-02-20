defmodule AndiWeb.ExtractSteps.ExtractHttpStepForm do
  @moduledoc """
  LiveComponent for an extract step with type HTTP
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  import Phoenix.HTML
  require Logger

  alias Andi.InputSchemas.Ingestions.ExtractHttpStep
  alias AndiWeb.EditLiveView.KeyValueEditor
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.Options
  alias AndiWeb.Views.DisplayNames
  alias AndiWeb.Helpers.ExtractStepHelpers
  alias Ecto.Changeset
  alias Andi.InputSchemas.StructTools
  alias AndiWeb.IngestionLiveView.ExtractSteps.ExtractStepForm
  alias Andi.UrlBuilder
  alias AndiWeb.Views.HttpStatusDescriptions

  def mount(socket) do
    {:ok,
     assign(socket,
       testing?: false,
       test_results: nil,
       visibility: "expanded",
       validation_status: "collapsed"
     )}
  end

  def render(assigns) do
    header_changesets =
      case Changeset.fetch_change(assigns.changeset, :headers) do
        {_, header_changesets} -> header_changesets
        :error -> []
      end

    query_param_changesets =
      case Changeset.fetch_change(assigns.changeset, :queryParams) do
        {_, query_param_changesets} -> query_param_changesets
        :error -> []
      end

    ~L"""
      <%= f = form_for @changeset, "#", [phx_change: :validate, phx_target: @myself, as: :form_data, id: @id] %>
        <div class="component-edit-section--<%= @visibility %>">
          <div class="extract-http-step-form-edit-section form-grid">
            <div class="extract-http-step-form__method">
              <%= label(f, :action, DisplayNames.get(:method), class: "label label--required", for: "#{@id}_http_method") %>
              <%= select(f, :action, get_http_methods(), [id: "#{@id}_http_method", class: "extract-http-step-form__method select", required: true]) %>
              <%= ErrorHelpers.error_tag(f, :action) %>
            </div>

            <div class="extract-http-step-form__url">
              <%= label(f, :url, DisplayNames.get(:url), class: "label label--required", for: "#{@id}_http_url") %>
              <%= url_input(f, :url, [id: "#{@id}_http_url", class: "input full-width", disabled: @testing?, required: true]) %>
              <%= ErrorHelpers.error_tag(f, :url, bind_to_input: false) %>
            </div>

            <%= live_component(@socket, KeyValueEditor, id: "#{@id}__key_pvalue_editor_queryParams", css_label: "source-query-params", form: f, field: :queryParams, parent_id: @id, changesets: query_param_changesets, parent_module: __MODULE__) %>
            <%= live_component(@socket, KeyValueEditor, id: "#{@id}__key_pvalue_editor_headers", css_label: "source-headers", form: f, field: :headers, parent_id: @id, changesets: header_changesets, parent_module: __MODULE__) %>

            <%= if input_value(f, :action) == "POST" do %>
              <div class="extract-http-step-form__body">
                <%= label(f, :body, DisplayNames.get(:body),  class: "label", for: "#{@id}_http_body") %>
                <%= textarea(f, :body, id: "#{@id}_http_body", class: "input full-width", phx_hook: "prettify", disabled: @testing?) %>
                <%= ErrorHelpers.error_tag(f, :body, bind_to_input: false) %>
              </div>
            <% end %>

            <div class="extract-http-step-form__test-section">
              <button
                type="button"
                class="extract_step__test-btn btn--primary btn--test btn btn--large btn--action"
                phx-click="test_url" phx-target="<%= @myself %>"
                <%= if @testing?, do: "disabled", else: "" %>
              >
                Test
              </button>
              <%= if @test_results do %>
                 <div class="test-status">
                 Status: <span class="test-status__code <%= status_class(@test_results) %>"><%= @test_results |> Map.get(:status) |> HttpStatusDescriptions.simple() %></span>
                 <%= status_tooltip(@test_results) %>
                 Time: <span class="test-status__time"><%= @test_results |> Map.get(:time) %></span> ms
                 </div>
               <% end %>
            </div>
          </div>
        </div>
      </form>
    """
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    extract_step = ExtractHttpStep.changeset(socket.assigns.changeset, form_data)

    ExtractStepForm.update_extract_step(extract_step, socket.assigns.id)

    {:noreply, socket}
  end

  def handle_event("validate", _, socket) do
    send(socket.parent_pid, :page_error)

    {:noreply, socket}
  end

  def handle_event("test_url", _, socket) do
    ExtractStepForm.update_test_url(socket.assigns.id)
    {:noreply, socket}
  end

  def update_key_value(field, changesets, id) do
    send_update(__MODULE__, id: id, field: field, changesets: changesets)
  end

  def update_test_url(compiled_steps, id) do
    send_update(__MODULE__, id: id, compiled_steps: compiled_steps)
  end

  def update(%{field: field, changesets: changesets}, socket) do
    applied_changes =
      Enum.map(changesets, fn changeset ->
        Changeset.apply_changes(changeset)
        |> StructTools.to_map()
      end)

    changes = %{field => applied_changes}

    extract_step =
      socket.assigns.changeset
      |> Changeset.delete_change(field)
      |> ExtractHttpStep.changeset(changes)

    AndiWeb.IngestionLiveView.ExtractSteps.ExtractStepForm.update_extract_step(extract_step, socket.assigns.id)

    {:ok, socket}
  end

  def update(%{compiled_steps: compiled_steps}, socket) do
    headers =
      fetch_changeset_field(socket.assigns.changeset, :headers, [])
      |> UrlBuilder.safe_evaluate_parameters(compiled_steps)

    query_params =
      fetch_changeset_field(socket.assigns.changeset, :queryParams, [])
      |> UrlBuilder.safe_evaluate_parameters(compiled_steps)

    url =
      fetch_changeset_field(socket.assigns.changeset, :url, "")
      |> String.split("?")
      |> hd()
      |> UrlBuilder.build_safe_url_path(compiled_steps)

    test_results = Andi.Services.UrlTest.test(url, query_params: query_params, headers: headers)

    {:ok, assign(socket, test_results: test_results)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  defp fetch_changeset_field(changeset, key, default \\ nil) do
    case Changeset.fetch_field(changeset, key) do
      {_, value} -> value
      :error -> default
    end
  end

  defp get_http_methods(), do: ExtractStepHelpers.map_to_dropdown_options(Options.http_method())

  defp status_class(%{status: status}) when status in 200..399, do: "test-status__code--good"
  defp status_class(%{status: _}), do: "test-status__code--bad"

  defp status_tooltip(%{status: status}) when status in 200..399, do: status_tooltip(%{status: status}, "shown")

  defp status_tooltip(%{status: status}, modifier \\ "shown") do
    assigns = %{
      description: HttpStatusDescriptions.get(status),
      modifier: modifier
    }

    ~E(<sup class="test-status__tooltip-wrapper"><i id="test-tooltip" phx-hook="addTooltip" data-tooltip-content="<%= @description %>" class="material-icons test-status__tooltip--<%= @modifier %>">info_outline</i></sup>)
  end
end
