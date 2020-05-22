defmodule DiscoveryApiWeb.Plugs.SecureHeaders do
  @moduledoc """
  A plug to add secure response headers on http traffic
  """
  def init(default), do: default

  def call(conn, _default) do
    Phoenix.Controller.put_secure_browser_headers(conn)
  end
end
