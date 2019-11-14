defmodule DiscoveryApiWeb.Utilities.EctoAccessUtils do
  @moduledoc """
  This module is the implementation of the DiscoveryApiWeb.Utilities.AccessUtils behavior for auth rules stored in Ecto
  """
  @behaviour DiscoveryApiWeb.Utilities.AccessUtils
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Schemas.Users

  def has_access?(%Model{private: false} = _dataset, _username), do: true

  def has_access?(%Model{private: true} = _dataset, nil), do: false

  def has_access?(%Model{private: true, organizationDetails: %{id: id}} = _dataset, username) do
    username
    |> Users.get_user_with_organizations(:subject_id)
    |> elem(1)
    |> Map.get(:organizations, [])
    |> Enum.any?(fn %{id: user_org_id} -> user_org_id == id end)
  end

  def has_access?(_base, _case), do: false
end
