defmodule AndiWeb.FooterLiveView do
  @moduledoc """
  LiveView for the footer bar
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
      <footer class="page-footer">
        <span class="left-side-text">
          <%= if get_left_side_link() do %>
            <a class="footer-link" href="<%= get_left_side_link() %>"><%= get_left_side_text() %></a>
          <% else %>
            <%= get_left_side_text() %>
          <% end %>
        </span>
        <span class="links">
          <%= for link <- get_right_links() do %>
            <a class="footer-link" href='<%= link["url"] %>'><%= link["linkText"] %></a>
          <% end %>
        </span>
      </footer>
    """
  end

  @spec __using__(any) :: {:import, [{:context, AndiWeb.FooterLiveView}, ...], [{:__aliases__, [...], [...]}, ...]}
  defmacro __using__(_opts \\ []) do
    quote do
      import AndiWeb.FooterLiveView
    end
  end

  def footer_render(is_curator) do
    live_component(AndiWeb.FooterLiveView, is_curator: is_curator)
  end

  def get_right_links() do
    env_var = Application.get_env(:andi, :andi_footer_right_links)
    Jason.decode!(env_var)
  end

  def get_left_side_text(), do: Application.get_env(:andi, :footer_left_side_text)
  def get_left_side_link(), do: Application.get_env(:andi, :footer_left_side_link)
end
