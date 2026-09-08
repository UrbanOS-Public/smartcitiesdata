defmodule Andi.Services.UserOrganizationAssociateServiceTest do
  use ExUnit.Case

  alias Andi.Services.UserOrganizationAssociateService
  alias Andi.Services.OrgStore
  alias Andi.InputSchemas.Organizations
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.Event, only: [user_organization_associate: 0]

  @instance_name Andi.instance_name()

  describe "associate/2" do
    setup do
      modules_to_mock = [OrgStore, Organizations, Andi.Schemas.AuditEvents, Brook.Event]

      Enum.each(modules_to_mock, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)

      Enum.each(modules_to_mock, fn module ->
        try do
          :meck.new(module, [:passthrough])
        catch
          :error, {:already_started, _} -> :ok
        end
      end)

      :meck.expect(Andi.Schemas.AuditEvents, :log_audit_event, fn _, _, _ -> %{} end)

      on_exit(fn ->
        Enum.each(modules_to_mock, fn module ->
          try do
            :meck.unload(module)
          catch
            _, _ -> :ok
          end
        end)
      end)

      :ok
    end

    test "sends an event when the org is found in the OrgStore (Redis)" do
      org = TDG.create_organization(%{id: "org_id"})
      user = %{subject_id: "auth0|1", email: "sample@example.com"}

      :meck.expect(OrgStore, :get, fn "org_id" -> {:ok, org} end)
      :meck.expect(Brook.Event, :send, fn @instance_name, user_organization_associate(), :andi, _ -> :ok end)

      assert :ok == UserOrganizationAssociateService.associate("org_id", [user])

      assert :meck.called(Brook.Event, :send, [@instance_name, user_organization_associate(), :andi, :_])
    end

    test "falls back to Postgres and still associates when the OrgStore (Redis) has no record" do
      user = %{subject_id: "auth0|1", email: "sample@example.com"}

      :meck.expect(OrgStore, :get, fn "org_id" -> {:ok, nil} end)
      :meck.expect(Organizations, :get, fn "org_id" -> %Andi.InputSchemas.Organization{id: "org_id"} end)
      :meck.expect(Brook.Event, :send, fn @instance_name, user_organization_associate(), :andi, _ -> :ok end)

      assert :ok == UserOrganizationAssociateService.associate("org_id", [user])

      assert :meck.called(Brook.Event, :send, [@instance_name, user_organization_associate(), :andi, :_])
    end

    test "returns an error when the org is missing from both the OrgStore and Postgres" do
      :meck.expect(OrgStore, :get, fn "nonexistent" -> {:ok, nil} end)
      :meck.expect(Organizations, :get, fn "nonexistent" -> nil end)

      assert {:error, :invalid_org} == UserOrganizationAssociateService.associate("nonexistent", [])
    end
  end
end
