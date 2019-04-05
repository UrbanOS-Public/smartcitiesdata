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
      |> DiscoveryApiWeb.RenderError.render_error(401, "Not Authorized")
      |> halt()
    end
  end

  defp is_authorized?(token, %{private: true} = dataset) do
    with {:ok, claims} <- Guardian.decode_and_verify(token),
         {:ok, resource} <- Guardian.resource_from_claims(claims) do
      resource
      |> extract_groups()
      |> Enum.member?(dataset.organizationDetails.dn)
    else
      {:error, error} ->
        Logger.error(inspect(error))
        false
    end
  end

  defp is_authorized?(_token, _unrestricted_dataset), do: true

  defp extract_groups(resource) do
    resource
    |> Map.get("memberOf", [])
    |> Enum.map(&extract_group/1)
  end

  defp extract_group(group) do
    group
    |> String.split(",")
    |> List.first()
    |> String.split("=")
    |> List.last()
  end
end
