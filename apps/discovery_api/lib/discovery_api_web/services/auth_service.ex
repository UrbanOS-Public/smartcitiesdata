defmodule DiscoveryApiWeb.Services.AuthService do
  @moduledoc """
  Provides authentication and authorization helper methods
  """

  alias DiscoveryApi.Data.Model

  def get_user(conn) do
    case Guardian.Plug.current_claims(conn) do
      %{"sub" => uid} -> uid
      _ -> nil
    end
  end

  def has_access?(%Model{private: false} = _dataset, _username), do: true

  def has_access?(%Model{private: true, organizationDetails: %{dn: dn}} = _dataset, username) do
    dn
    |> get_members()
    |> Enum.member?(username)
  end

  def has_access?(_base, _case), do: false

  defp get_members(org_dn) do
    %{"cn" => cn, "ou" => ou} =
      org_dn
      |> Paddle.Parsing.dn_to_kwlist()
      |> Map.new()

    user = Application.get_env(:discovery_api, :ldap_user)
    pass = Application.get_env(:discovery_api, :ldap_pass)
    PaddleWrapper.authenticate(user, pass)

    PaddleWrapper.get(base: [ou: ou], filter: [cn: cn])
    |> elem(1)
    |> List.first()
    |> Map.get("member", [])
    |> Enum.map(&extract_uid/1)
  end

  defp extract_uid(dn) do
    dn
    |> Paddle.Parsing.dn_to_kwlist()
    |> Map.new()
    |> Map.get("uid")
  end
end
