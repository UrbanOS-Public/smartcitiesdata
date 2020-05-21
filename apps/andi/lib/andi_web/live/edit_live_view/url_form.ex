defmodule AndiWeb.EditLiveView.UrlForm do
  @moduledoc """
  LiveComponent for editing dataset URL
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  alias AndiWeb.ErrorHelpers
  alias Andi.InputSchemas.DisplayNames
  alias AndiWeb.EditLiveView.KeyValueEditor

  def mount(socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~L"""
        <div class="url-form form-section form-grid">
          <h2 class="url-form__top-header edit-page__box-header">Configure Upload</h2>
          <div class="url-form__source-url">
            <%= label(@technical, :sourceUrl, DisplayNames.get(:sourceUrl), class: "label label--required") %>
            <%= text_input(@technical, :sourceUrl, class: "input full-width", disabled: @testing) %>
            <%= ErrorHelpers.error_tag(@technical, :sourceUrl) %>
          </div>

          <%= live_component(@socket, KeyValueEditor, id: :key_value_editor_source_query_params, css_label: "source-query-params", form: @technical, field: :sourceQueryParams ) %>
          <%= live_component(@socket, KeyValueEditor, id: :key_value_editor_source_headers, css_label: "source-headers", form: @technical, field: :sourceHeaders ) %>

          <div class="url-form__test-section">
            <button type="button" class="url-form__test-btn btn--test btn btn--large btn--action" phx-click="test_url" <%= disabled?(@testing) %>>Test</button>
            <%= if @test_results do %>
              <div class="test-status">
              Status: <span class="test-status__code <%= status_class(@test_results) %>"><%= @test_results |> Map.get(:status) %></span>
              Time: <span class="test-status__time"><%= @test_results |> Map.get(:time) %></span> ms
              </div>
            <% end %>
          </div>
        </div>

    """
  end

  defp disabled?(true), do: "disabled"
  defp disabled?(_), do: ""

  defp status_class(%{status: status}) when status in 200..399, do: "test-status__code--good"
  defp status_class(%{status: _}), do: "test-status__code--bad"
end
