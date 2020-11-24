defmodule AndiWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use AndiWeb, :controller
      use AndiWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: AndiWeb

      import Phoenix.LiveView.Controller, only: [live_render: 2, live_render: 3]

      import Plug.Conn
      import AndiWeb.Gettext

      alias AndiWeb.Router.Helpers, as: Routes
      import AndiWeb.Auth.EnsureAccessLevelForRoute, only: [access_levels: 1]
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/andi_web/templates",
        namespace: AndiWeb

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_flash: 1, get_flash: 2, view_module: 1]

      import Phoenix.LiveView.Helpers, only: [live_render: 2, live_render: 3]

      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      import AndiWeb.ErrorHelpers
      import AndiWeb.Gettext
      alias AndiWeb.Router.Helpers, as: Routes
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import AndiWeb.Gettext
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView
      import AndiWeb.ErrorHelpers
      import Phoenix.HTML.Form
      import Phoenix.HTML.Link
      alias AndiWeb.Router.Helpers, as: Routes
      import AndiWeb.Auth.EnsureAccessLevelForRoute, only: [access_levels: 1]
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
