defmodule Andi.Services.UserOrganizationAssociateServiceTest do
  use ExUnit.Case
  use Placebo

  alias Andi.Services.UserOrganizationAssociateService
  alias Andi.Services.OrgStore
  alias Andi.InputSchemas.Organizations
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.Event, only: [user_organization_associate: 0]

  @instance_name Andi.instance_name()

  describe "associate/2" do
    setup do
      allow(Andi.Schemas.AuditEvents.log_audit_event(any(), any(), any()), return: %{})
      :ok
    end

    test "sends an event when the org is found in the OrgStore (Redis)" do
      org = TDG.create_organization(%{id: "org_id"})
      user = %{subject_id: "auth0|1", email: "sample@example.com"}

      allow(OrgStore.get("org_id"), return: {:ok, org})
      allow(Brook.Event.send(@instance_name, user_organization_associate(), :andi, any()), return: :ok)

      assert :ok == UserOrganizationAssociateService.associate("org_id", [user])

      assert_called Brook.Event.send(@instance_name, user_organization_associate(), :andi, any())
    end

    test "falls back to Postgres and still associates when the OrgStore (Redis) has no record" do
      user = %{subject_id: "auth0|1", email: "sample@example.com"}

      allow(OrgStore.get("org_id"), return: {:ok, nil})
      allow(Organizations.get("org_id"), return: %Andi.InputSchemas.Organization{id: "org_id"})
      allow(Brook.Event.send(@instance_name, user_organization_associate(), :andi, any()), return: :ok)

      assert :ok == UserOrganizationAssociateService.associate("org_id", [user])

      assert_called Brook.Event.send(@instance_name, user_organization_associate(), :andi, any())
    end

    test "returns an error when the org is missing from both the OrgStore and Postgres" do
      allow(OrgStore.get("nonexistent"), return: {:ok, nil})
      allow(Organizations.get("nonexistent"), return: nil)

      assert {:error, :invalid_org} == UserOrganizationAssociateService.associate("nonexistent", [])
    end
  end
end
