defmodule DiscoveryApi.Services.PaddleService do
  @moduledoc """
  A service wrapper for paddle to do dn lookups and extract user id
  """

  def get_members(org_dn) do
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
