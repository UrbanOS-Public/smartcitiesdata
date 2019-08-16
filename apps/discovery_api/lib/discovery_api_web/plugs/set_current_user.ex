defmodule DiscoveryApiWeb.Plugs.SetCurrentUser do
  @moduledoc """
  Plug to get the requested dataset (by org and dataset name or by dataset id) or return 404
  """

  require Logger
  import Plug.Conn

  def init(default), do: default

  def call(conn, _) do
    current_user =
      case Guardian.Plug.current_claims(conn) do
        %{"sub" => uid} -> uid
        _ -> nil
      end

    assign(conn, :current_user, current_user)
  end
end
