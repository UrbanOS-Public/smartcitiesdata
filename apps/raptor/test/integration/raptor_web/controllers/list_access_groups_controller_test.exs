defmodule Raptor.ListAccessGroupsControllerTest do
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

  describe "listAccessGroups" do

    test "returns an empty list of access groups when there are no valid access groups for the given user" do

      {:ok, %Tesla.Env{body: body}} =
        get("/api/listAccessGroups?user_id=124",
          headers: [{"content-type", "application/json"}]
        )

      assert body == "{\"access_groups\":[]}"
    end

    test "returns a list of access groups when there are access group authorized for the given user" do
      relation = send_user_access_group_associate_event("access_group_id", "123")

      {:ok, %Tesla.Env{body: body}} =
        get("/api/listAccessGroups?user_id=123",
          headers: [{"content-type", "application/json"}]
        )

      assert body == "{\"access_groups\":[\"access_group_id\"]}"
    end

    test "returns an empty list of access groups when there are no valid access groups for the given dataset" do

      {:ok, %Tesla.Env{body: body}} =
        get("/api/listAccessGroups?dataset_id=124",
          headers: [{"content-type", "application/json"}]
        )

      assert body == "{\"access_groups\":[]}"
    end

    test "returns a list of access groups when there are access group authorized for the given dataset" do
      relation = send_dataset_access_group_associate_event("access_group_id", "123")

      {:ok, %Tesla.Env{body: body}} =
        get("/api/listAccessGroups?dataset_id=123",
          headers: [{"content-type", "application/json"}]
        )

      assert body == "{\"access_groups\":[\"access_group_id\"]}"
    end
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
end
