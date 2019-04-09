defmodule DiscoveryApi.Plugs.Restrictor do
  @moduledoc false
  require Logger
  import Plug.Conn
  alias DiscoveryApi.Auth.Guardian

  def init(default), do: default

  def call(conn, _) do
    token = conn |> Plug.Conn.get_req_header("token") |> List.first()

    if is_authorized?(token, conn.assigns.dataset) do
      conn
    else
      conn
      |> DiscoveryApiWeb.RenderError.render_error(404, "Not Found")
      |> halt()
    end
  end

  defp is_authorized?(token, %{private: true} = dataset) do
    with {:ok, claims} <- Guardian.decode_and_verify(token),
         {:ok, resource} <- Guardian.resource_from_claims(claims) do
      uid = parse_uid(resource)

      dataset.organizationDetails.dn
      |> get_members()
      |> Enum.member?(uid)
    else
      {:error, error} ->
        Logger.error(inspect(error))
        false
    end
  end

  defp is_authorized?(_token, _unrestricted_dataset), do: true

  defp extract_cn(dn) do
    dn
    |> String.split(",")
    |> Enum.find(fn x -> String.contains?(x, "cn=") end)
    |> String.split("=")
    |> List.last()
  end

  defp get_members(org_dn) do
    Paddle.get(base: org_dn)
    |> elem(1)
    |> List.first()
    |> Map.get("member", [])
    |> Enum.map(&extract_cn/1)
  end

  defp parse_uid(resource) do
    resource
    |> Map.get("uid")
    |> List.first()
  end
end
