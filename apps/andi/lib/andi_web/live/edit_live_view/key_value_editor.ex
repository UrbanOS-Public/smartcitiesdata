defmodule AndiWeb.EditLiveView.KeyValueEditor do
  @moduledoc """
    LiveComponent for an nested key/value form
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  import AndiWeb.ErrorHelpers

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>" class="url-form__<%= @field %>">
      <%= if has_values(input_value(@form, @field)) do %>
        <%= inputs_for @form, @field, fn f -> %>
          <%= text_input(f, :key, class: "input full-width url-form__#{@field}-key-input #{input_value(f, :id)}", placeholder: "key") %>
          <%= text_input(f, :value, class: "input full-width url-form__#{@field}-value-input #{input_value(f, :id)}", placeholder: "value") %>
          <button type="button" class="url-form__<%= @field %>-delete-btn btn btn--large btn--action" phx-click="remove" phx-value-id="<%= input_value(f, :id) %>" phx-value-field="<%= @field %>">X</button>
        <% end %>
      <% end %>
      <button type="button" class="url-form__<%= @field %>-add-btn btn btn--large btn--action" phx-click="add" phx-value-field="<%= @field %>">+</button>
      <%= error_tag_live(@form, @field) %>
    </div>
    """
  end

  def handle_event("add", payload, socket) do
    send(self(), {:add_key_value, payload})
    {:noreply, socket}
  end

  def handle_event("remove", payload, socket) do
    send(self(), {:remove_key_value, payload})
    {:noreply, socket}
  end

  defp has_values(nil), do: false
  defp has_values([]), do: false
  defp has_values(_), do: true
end
