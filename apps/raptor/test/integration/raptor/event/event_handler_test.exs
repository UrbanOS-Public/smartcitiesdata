defmodule Raptor.Event.EventHandlerTest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper
  alias Raptor.Services.DatasetStore
  alias Raptor.Schemas.Dataset
  alias Raptor.Services.UserOrgAssocStore
  alias Raptor.Schemas.UserOrgAssoc
  alias Raptor.Services.UserAccessGroupRelationStore
  alias Raptor.Schemas.UserAccessGroupRelation
  alias Raptor.Services.DatasetAccessGroupRelationStore
  alias Raptor.Schemas.DatasetAccessGroupRelation

  import SmartCity.Event,
    only: [
      dataset_update: 0,
      user_organization_associate: 0,
      user_organization_disassociate: 0,
      user_access_group_associate: 0,
      user_access_group_disassociate: 0,
      dataset_access_group_associate: 0,
      dataset_access_group_disassociate: 0
    ]

  @instance_name Raptor.instance_name()

  describe "dataset:update" do
    test "when a dataset update event is received, a Raptor dataset is stored in Redis" do
      dataset = TDG.create_dataset(%{})
      system_name = dataset.technical.systemName
      Brook.Event.send(@instance_name, dataset_update(), :test, dataset)

      expected_raptor_dataset = %Dataset{
        dataset_id: dataset.id,
        org_id: dataset.technical.orgId,
        system_name: system_name,
        is_private: dataset.technical.private
      }

      eventually(fn ->
        raptor_dataset = DatasetStore.get(system_name)
        assert raptor_dataset == expected_raptor_dataset
      end)
    end
  end

  describe "user_organization:associate" do
    test "when a user_organization_associate event is received, a user_organization_associate event is stored in Redis" do
      association = %SmartCity.UserOrganizationAssociate{
        org_id: "ds9",
        subject_id: "sisko",
        email: "ben@starfleet.com"
      }

      Brook.Event.send(
        Raptor.instance_name(),
        user_organization_associate(),
        :testing,
        association
      )

      expected_raptor_assoc = %UserOrgAssoc{
        user_id: "sisko",
        org_id: "ds9",
        email: "ben@starfleet.com"
      }

      eventually(fn ->
        raptor_user_org_assoc = UserOrgAssocStore.get("sisko", "ds9")
        assert expected_raptor_assoc == raptor_user_org_assoc
      end)
    end
  end

  describe "user_access_group:associate" do
    test "when a user_access_group_associate event is received, a user_organization_associate event is stored in Redis" do
      association = %SmartCity.UserAccessGroupRelation{
        access_group_id: "ds9",
        subject_id: "sisko"
      }

      Brook.Event.send(
        Raptor.instance_name(),
        user_access_group_associate(),
        :testing,
        association
      )

      expected_raptor_assoc = %Raptor.Schemas.UserAccessGroupRelation{
        user_id: "sisko",
        access_group_id: "ds9"
      }

      eventually(fn ->
        raptor_user_access_group_relation = UserAccessGroupRelationStore.get("sisko", "ds9")
        assert expected_raptor_assoc == raptor_user_access_group_relation
      end)
    end
  end

  describe "user_access_group:disassociate" do
    test "when a user_access_group_disassociate event is received, a user_organization_disassociate event is removed from Redis" do
      association = %SmartCity.UserAccessGroupRelation{
        access_group_id: "ds9",
        subject_id: "sisko"
      }

      Brook.Event.send(
        Raptor.instance_name(),
        user_access_group_associate(),
        :testing,
        association
      )

      expected_raptor_assoc = %Raptor.Schemas.UserAccessGroupRelation{
        user_id: "sisko",
        access_group_id: "ds9"
      }

      eventually(fn ->
        raptor_user_access_group_relation = UserAccessGroupRelationStore.get("sisko", "ds9")
        assert expected_raptor_assoc == raptor_user_access_group_relation
      end)

      Brook.Event.send(
        Raptor.instance_name(),
        user_access_group_disassociate(),
        :testing,
        association
      )

      eventually(fn ->
        raptor_user_access_group_relation = UserAccessGroupRelationStore.get("sisko", "ds9")
        assert %{} == raptor_user_access_group_relation
      end)
    end
  end

  describe "dataset_access_group:associate" do
    test "when a dataset_access_group_associate event is received, a dataset_organization_associate event is stored in Redis" do
      association = %SmartCity.DatasetAccessGroupRelation{
        access_group_id: "ds9",
        dataset_id: "captains log"
      }

      Brook.Event.send(
        Raptor.instance_name(),
        dataset_access_group_associate(),
        :testing,
        association
      )

      expected_raptor_assoc = %Raptor.Schemas.DatasetAccessGroupRelation{
        dataset_id: "captains log",
        access_group_id: "ds9"
      }

      eventually(fn ->
        raptor_dataset_access_group_relation = DatasetAccessGroupRelationStore.get("captains log", "ds9")
        assert expected_raptor_assoc == raptor_dataset_access_group_relation
      end)
    end
  end

  describe "dataset_access_group:disassociate" do
    test "when a dataset_access_group_disassociate event is received, a dataset_access_group_disassociate event is remved from Redis" do
      association = %SmartCity.DatasetAccessGroupRelation{
        access_group_id: "ds9",
        dataset_id: "captains log"
      }

      Brook.Event.send(
        Raptor.instance_name(),
        dataset_access_group_associate(),
        :testing,
        association
      )

      expected_raptor_assoc = %Raptor.Schemas.DatasetAccessGroupRelation{
        dataset_id: "captains log",
        access_group_id: "ds9"
      }

      eventually(fn ->
        raptor_dataset_access_group_relation = DatasetAccessGroupRelationStore.get("captains log", "ds9")
        assert expected_raptor_assoc == raptor_dataset_access_group_relation
      end)

      Brook.Event.send(
        Raptor.instance_name(),
        dataset_access_group_disassociate(),
        :testing,
        association
      )

      eventually(fn ->
        raptor_dataset_access_group_relation = DatasetAccessGroupRelationStore.get("captains log", "ds9")
        assert %{}== raptor_dataset_access_group_relation
      end)
    end
  end


  describe "user_organization:disassociate" do
    setup do
      association = %SmartCity.UserOrganizationAssociate{
        org_id: "ds9",
        subject_id: "kira",
        email: "nerys@starfleet.com"
      }

      Brook.Event.send(
        Raptor.instance_name(),
        user_organization_associate(),
        :testing,
        association
      )

      expected_raptor_assoc = %UserOrgAssoc{
        user_id: "kira",
        org_id: "ds9",
        email: "nerys@starfleet.com"
      }

      eventually(fn ->
        raptor_user_org_assoc = UserOrgAssocStore.get("kira", "ds9")
        assert expected_raptor_assoc == raptor_user_org_assoc
      end)
    end

    test "when a user_organization_disassociate event is received, a user_organization_associate event is deleted from Redis" do
      disassociation = %SmartCity.UserOrganizationDisassociate{org_id: "ds9", subject_id: "kira"}

      Brook.Event.send(
        Raptor.instance_name(),
        user_organization_disassociate(),
        :testing,
        disassociation
      )

      eventually(fn ->
        raptor_user_org_assoc = UserOrgAssocStore.get("kira", "ds9")
        assert %{} == raptor_user_org_assoc
      end)
    end
  end
end
