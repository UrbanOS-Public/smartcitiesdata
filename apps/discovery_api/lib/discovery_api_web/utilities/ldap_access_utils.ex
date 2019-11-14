defmodule DiscoveryApiWeb.Utilities.LdapAccessUtils do
  @moduledoc """
  This module is the implementation of the DiscoveryApiWeb.Utilities.AccessUtils behavior for LDAP
  """
  @behaviour DiscoveryApiWeb.Utilities.AccessUtils
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Services.PaddleService

  def has_access?(%Model{private: false} = _dataset, _username), do: true

  def has_access?(%Model{private: true} = _dataset, nil), do: false

  def has_access?(%Model{private: true, organizationDetails: %{dn: dn}} = _dataset, username) do
    dn
    |> PaddleService.get_members()
    |> Enum.member?(username)
  end

  def has_access?(_base, _case), do: false
end
