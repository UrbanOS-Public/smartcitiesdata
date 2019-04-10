defmodule DiscoveryApi.Plugs.Restrictor do
  @moduledoc false
  require Logger
  import Plug.Conn
  alias DiscoveryApi.Auth.Guardian
  alias Guardian.Plug, as: GuardianPlug

  def init(default), do: default

  def call(conn, _) do
    case is_authorized?(conn, conn.assigns.dataset) do
      true ->
        conn

      false ->
        conn
        |> DiscoveryApiWeb.RenderError.render_error(404, "Not Found")
        |> halt()
    end
  end

  defp is_authorized?(conn, %{private: true} = dataset) do
    case GuardianPlug.current_claims(conn) do
      %{"sub" => uid} ->
        dataset.organizationDetails.dn
        |> get_members()
        |> Enum.member?(uid)

      error ->
        Logger.error(inspect(error))
        false
    end
  end

  defp is_authorized?(_token, _unrestricted_dataset), do: true

  defp extract_uid(dn) do
    dn
    |> Paddle.Parsing.dn_to_kwlist()
    |> Map.new()
    |> Map.get("uid")
  end

  defp get_members(org_dn) do
    %{"cn" => cn, "ou" => ou} =
      org_dn
      |> Paddle.Parsing.dn_to_kwlist()
      |> Map.new()

    Paddle.get(base: [ou: ou], filter: [cn: cn])
    |> elem(1)
    |> List.first()
    |> Map.get("member", [])
    |> Enum.map(&extract_uid/1)
  end
end
