defmodule DiscoveryApiWeb.Plugs.SetAllowedOrigin do
  @moduledoc """
  Assigns allowed_origin to conn based upon the origin host and allowed_origins env variable.
  It is assigned a boolean if origin is available in the request header and nil if it is not.
  """

  def init(default), do: default

  def call(%Plug.Conn{} = conn, _opts) do
    origin_host_from_request = get_origin_host(conn)
    is_allowed = origin_contained_in_allowed_origins?(origin_host_from_request)
    Plug.Conn.assign(conn, :allowed_origin, is_allowed)
  end

  defp get_origin_host(%Plug.Conn{} = conn) do
    conn
    |> Plug.Conn.get_req_header("origin")
    |> List.first()
  end

  defp origin_contained_in_allowed_origins?(nil), do: nil
  defp origin_contained_in_allowed_origins?("null"), do: nil

  defp origin_contained_in_allowed_origins?(origin_host) do
    Application.get_env(:discovery_api, :allowed_origins, [])
    |> Enum.any?(&origin_is_allowed?(&1, origin_host))
  end

  defp origin_is_allowed?(allowed_origin, origin_host_from_request) do
    is_full_domain_equal = allowed_origin == origin_host_from_request
    is_higher_domain_equal = String.ends_with?(origin_host_from_request, ".#{allowed_origin}")
    is_full_domain_equal || is_higher_domain_equal
  end
end
