defmodule Andi.Services.UserOrganizationAssociateService do
  @moduledoc """
  Service for associating a user with an organization
  """
  import SmartCity.Event, only: [user_organization_associate: 0]
  alias SmartCity.Organization
  alias SmartCity.UserOrganizationAssociate
  alias Andi.Services.OrgStore
  alias Andi.InputSchemas.Organizations
  require Logger

  @doc """
  Associate a user to an organization
  """
  def associate(org_id, users) do
    case OrgStore.get(org_id) do
      {:ok, %Organization{}} ->
        send_events(org_id, users)

      {:ok, nil} ->
        # Falls back to Postgres so this still works after a Redis key reset,
        # where the org exists in Postgres but hasn't yet been resynced to Redis.
        case Organizations.get(org_id) do
          nil -> {:error, :invalid_org}
          _org -> send_events(org_id, users)
        end

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
    {:ok, event_data} = UserOrganizationAssociate.new(%{subject_id: user.subject_id, org_id: org_id, email: user.email})
    Andi.Schemas.AuditEvents.log_audit_event(:api, user_organization_associate(), event_data)
    Brook.Event.send(:andi, user_organization_associate(), :andi, event_data)
  end

  defp error?({:error, _}), do: true
  defp error?(_), do: false
end
