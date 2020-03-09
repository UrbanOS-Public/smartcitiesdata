defmodule Andi.Services.UserOrganizationAssociateService do
  @moduledoc """
  Service for associating a user with an organization
  """
  import SmartCity.Event, only: [user_organization_associate: 0]
  alias SmartCity.Organization
  alias SmartCity.UserOrganizationAssociate
  alias Andi.DatasetStore
  require Logger

  @doc """
  Associate a user to an organization
  """
  def associate(org_id, users) do
    case DatasetStore.get_org(org_id) do
      {:ok, %Organization{}} ->
        send_events(org_id, users)

      {:ok, nil} ->
        {:error, :invalid_org}

      {:error, reason} ->
        Logger.error("Unable to retrieve organization: #{reason}")
        {:error, reason}
    end
  end

  defp send_events(org_id, users) do
    Enum.map(users, &send_event(org_id, &1))
    |> Enum.find(&error?/1)
    |> case do
      nil ->
        :ok

      {:error, reason} ->
        Logger.error("Unable to send event: #{reason}")
        {:error, reason}
    end
  end

  defp send_event(org_id, user) do
    {:ok, event_data} = UserOrganizationAssociate.new(%{user_id: user, org_id: org_id})
    Brook.Event.send(:andi, user_organization_associate(), :andi, event_data)
  end

  defp error?({:error, _}), do: true
  defp error?(_), do: false
end
