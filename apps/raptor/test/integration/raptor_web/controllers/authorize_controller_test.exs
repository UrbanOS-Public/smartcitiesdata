defmodule Raptor.AuthorizeControllerTest do
  use ExUnit.Case
  use Placebo

  use Tesla
  use Properties, otp_app: :raptor

  import SmartCity.TestHelper, only: [eventually: 1]
  import SmartCity.Event
  alias SmartCity.TestDataGenerator, as: TDG
  alias Raptor.Services.DatasetStore
  alias Raptor.Schemas.Dataset
  alias Raptor.Services.UserOrgAssocStore
  alias Raptor.Schemas.UserOrgAssoc
  alias Raptor.Services.Auth0Management
  alias Raptor.Services.UserAccessGroupRelationStore
  alias Raptor.Schemas.UserAccessGroupRelation
  alias Raptor.Services.DatasetAccessGroupRelationStore
  alias Raptor.Schemas.DatasetAccessGroupRelation

  @instance_name Raptor.instance_name()

  plug(Tesla.Middleware.BaseUrl, "http://localhost:4002")
  getter(:kafka_broker, generic: true)

  describe "authorize" do
    setup do
      allow(Auth0Management.get_users_by_api_key("fakeApiKey"),
        return: {:ok, [%{"email_verified" => true, "user_id" => "123"}]}
      )

      :ok
    end

    test "returns is_authorized=false when the user does not have permissions to access the requested dataset" do
      is_private_dataset = true
      dataset = create_and_send_dataset_event(is_private_dataset)
      system_name = dataset.technical.systemName

      {:ok, %Tesla.Env{body: body}} =
        get("/api/authorize?apiKey=fakeApiKey&systemName=#{system_name}",
          headers: [{"content-type", "application/json"}]
        )

      assert body == "{\"is_authorized\":false}"
    end

    test "returns is_authorized=true when the user has permissions to access the requested dataset" do
      is_private_dataset = true
      dataset = create_and_send_dataset_event(is_private_dataset)
      system_name = dataset.technical.systemName
      send_user_org_associate_event(dataset.technical.orgId, "123", "nicole@starfleet.com")

      {:ok, %Tesla.Env{body: body}} =
        get("/api/authorize?apiKey=fakeApiKey&systemName=#{system_name}",
          headers: [{"content-type", "application/json"}]
        )

      assert body == "{\"is_authorized\":true}"
    end

    test "returns is_authorized=true when the user has permissions to access the requested dataset via an access group" do
      is_private_dataset = true
      dataset = create_and_send_dataset_event(is_private_dataset)
      system_name = dataset.technical.systemName
      send_dataset_access_group_associate_event("access_group_id", dataset.id)
      send_user_access_group_associate_event("access_group_id", "123")

      {:ok, %Tesla.Env{body: body}} =
        get("/api/authorize?apiKey=fakeApiKey&systemName=#{system_name}",
          headers: [{"content-type", "application/json"}]
        )

      assert body == "{\"is_authorized\":true}"
    end

    test "returns is_authorized=false when the user's permissions to access the requested dataset are revoked" do
      is_private_dataset = true
      dataset = create_and_send_dataset_event(is_private_dataset)
      system_name = dataset.technical.systemName
      send_user_org_associate_event(dataset.technical.orgId, "123", "nicole@starfleet.com")

      {:ok, %Tesla.Env{body: body}} =
        get("/api/authorize?apiKey=fakeApiKey&systemName=#{system_name}",
          headers: [{"content-type", "application/json"}]
        )

      assert body == "{\"is_authorized\":true}"
      send_user_org_disassociate_event(dataset.technical.orgId, "123")

      {:ok, %Tesla.Env{body: body}} =
        get("/api/authorize?apiKey=fakeApiKey&systemName=#{system_name}",
          headers: [{"content-type", "application/json"}]
        )

      assert body == "{\"is_authorized\":false}"
    end

    test "returns is_authorized=false when the user's permissions to access the requested dataset are revoked via access groups" do
      is_private_dataset = true
      dataset = create_and_send_dataset_event(is_private_dataset)
      system_name = dataset.technical.systemName
      send_user_access_group_associate_event("access_group_id", "123")
      send_dataset_access_group_associate_event("access_group_id", dataset.id)

      {:ok, %Tesla.Env{body: body}} =
        get("/api/authorize?apiKey=fakeApiKey&systemName=#{system_name}",
          headers: [{"content-type", "application/json"}]
        )

      assert body == "{\"is_authorized\":true}"
      send_user_access_group_disassociate_event("access_group_id", "123")
      send_dataset_access_group_disassociate_event("access_group_id", dataset.id)

      {:ok, %Tesla.Env{body: body}} =
        get("/api/authorize?apiKey=fakeApiKey&systemName=#{system_name}",
          headers: [{"content-type", "application/json"}]
        )

      assert body == "{\"is_authorized\":false}"
    end

    test "returns is_authorized=true when the dataset is public" do
      is_private_dataset = false
      dataset = create_and_send_dataset_event(is_private_dataset)
      system_name = dataset.technical.systemName
      send_user_org_associate_event(dataset.technical.orgId, "123", "nicole@starfleet.com")

      {:ok, %Tesla.Env{body: body}} =
        get("/api/authorize?systemName=#{system_name}",
          headers: [{"content-type", "application/json"}]
        )

      assert body == "{\"is_authorized\":true}"
    end
  end

  def create_and_send_dataset_event(private \\ false)

  def create_and_send_dataset_event(private) when private == true do
    dataset =
      TDG.create_dataset(%{
        technical: %{org_id: "1234-5678", system_name: "some_org___some_data", private: true}
      })

    Brook.Event.send(@instance_name, dataset_update(), :test, dataset)

    expected_raptor_dataset = %Dataset{
      dataset_id: dataset.id,
      org_id: dataset.technical.orgId,
      system_name: dataset.technical.systemName,
      is_private: dataset.technical.private
    }

    eventually(fn ->
      raptor_dataset = DatasetStore.get(dataset.technical.systemName)
      assert raptor_dataset == expected_raptor_dataset
    end)

    dataset
  end

  def create_and_send_dataset_event(private) when private == false do
    dataset = TDG.create_dataset(%{})
    Brook.Event.send(@instance_name, dataset_update(), :test, dataset)

    expected_raptor_dataset = %Dataset{
      dataset_id: dataset.id,
      org_id: dataset.technical.orgId,
      system_name: dataset.technical.systemName,
      is_private: dataset.technical.private
    }

    eventually(fn ->
      raptor_dataset = DatasetStore.get(dataset.technical.systemName)
      assert raptor_dataset == expected_raptor_dataset
    end)

    dataset
  end

  def send_user_org_disassociate_event(org_id, subject_id) do
    disassociation = %SmartCity.UserOrganizationDisassociate{
      org_id: org_id,
      subject_id: subject_id
    }

    Brook.Event.send(
      Raptor.instance_name(),
      user_organization_disassociate(),
      :testing,
      disassociation
    )

    eventually(fn ->
      raptor_user_org_assoc = UserOrgAssocStore.get(subject_id, org_id)
      assert %{} == raptor_user_org_assoc
    end)
  end

  def send_user_org_associate_event(org_id, subject_id, email) do
    association = %SmartCity.UserOrganizationAssociate{
      org_id: org_id,
      subject_id: subject_id,
      email: email
    }

    Brook.Event.send(Raptor.instance_name(), user_organization_associate(), :testing, association)

    expected_raptor_assoc = %UserOrgAssoc{user_id: subject_id, org_id: org_id, email: email}

    eventually(fn ->
      raptor_user_org_assoc = UserOrgAssocStore.get(subject_id, org_id)
      assert expected_raptor_assoc == raptor_user_org_assoc
    end)
  end

  def send_user_access_group_associate_event(access_group_id, subject_id) do
    association = %SmartCity.UserAccessGroupRelation{
      access_group_id: access_group_id,
      subject_id: subject_id
    }

    Brook.Event.send(Raptor.instance_name(), user_access_group_associate(), :testing, association)

    expected_raptor_assoc = %UserAccessGroupRelation{
      user_id: subject_id,
      access_group_id: access_group_id
    }

    eventually(fn ->
      raptor_user_access_group_assoc =
        UserAccessGroupRelationStore.get(subject_id, access_group_id)

      assert expected_raptor_assoc == raptor_user_access_group_assoc
    end)
  end

  def send_user_access_group_disassociate_event(access_group_id, subject_id) do
    association = %SmartCity.UserAccessGroupRelation{
      access_group_id: access_group_id,
      subject_id: subject_id
    }

    Brook.Event.send(
      Raptor.instance_name(),
      user_access_group_disassociate(),
      :testing,
      association
    )

    eventually(fn ->
      raptor_user_access_group_assoc =
        UserAccessGroupRelationStore.get(subject_id, access_group_id)

      assert %{} == raptor_user_access_group_assoc
    end)
  end

  def send_dataset_access_group_associate_event(access_group_id, dataset_id) do
    association = %SmartCity.DatasetAccessGroupRelation{
      access_group_id: access_group_id,
      dataset_id: dataset_id
    }

    Brook.Event.send(
      Raptor.instance_name(),
      dataset_access_group_associate(),
      :testing,
      association
    )

    expected_raptor_assoc = %DatasetAccessGroupRelation{
      dataset_id: dataset_id,
      access_group_id: access_group_id
    }

    eventually(fn ->
      raptor_dataset_access_group_assoc =
        DatasetAccessGroupRelationStore.get(dataset_id, access_group_id)

      assert expected_raptor_assoc == raptor_dataset_access_group_assoc
    end)
  end

  def send_dataset_access_group_disassociate_event(access_group_id, dataset_id) do
    association = %SmartCity.DatasetAccessGroupRelation{
      access_group_id: access_group_id,
      dataset_id: dataset_id
    }

    Brook.Event.send(
      Raptor.instance_name(),
      dataset_access_group_disassociate(),
      :testing,
      association
    )

    eventually(fn ->
      raptor_dataset_access_group_assoc =
        DatasetAccessGroupRelationStore.get(dataset_id, access_group_id)

      assert %{} == raptor_dataset_access_group_assoc
    end)
  end
end
