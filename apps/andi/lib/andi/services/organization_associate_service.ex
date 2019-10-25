defmodule Andi.Services.OrganizationAssociateService do
  @moduledoc """
  Service for associating a user with an organization
  """
  import Andi
  import SmartCity.Event, only: [user_organization_associate: 0]
  alias SmartCity.UserOrganizationAssociate

  @doc """
  Associate a user to an organization
  """
  def associate(org_id, users) do
    Enum.each(users, fn user ->
      {:ok, event_data} = UserOrganizationAssociate.new(%{user_id: user, org_id: org_id})
      Brook.Event.send(:andi, user_organization_associate(), :andi, event_data)
    end)
  end
end
