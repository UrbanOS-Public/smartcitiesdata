defmodule Raptor.Event.EventHandlerTest do
  use ExUnit.Case
  use Placebo

  import SmartCity.Event,
    only: [
      user_organization_associate: 0,
      user_organization_disassociate: 0,
      user_access_group_associate: 0,
      user_access_group_disassociate: 0,
      dataset_update: 0,
      dataset_access_group_associate: 0,
      dataset_access_group_disassociate: 0
    ]

  alias Raptor.Event.EventHandler
  alias Raptor.Services.UserOrgAssocStore
  alias Raptor.Services.DatasetStore
  alias Raptor.Services.UserAccessGroupRelationStore
  alias Raptor.Services.DatasetAccessGroupRelationStore
  alias Raptor.Schemas.UserOrgAssoc
  alias Raptor.Schemas.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  describe "handle_event/1 user_access_group_associate" do
    setup do
      {:ok, association_event} =
        SmartCity.UserAccessGroupRelation.new(%{
          subject_id: "user_id",
          access_group_id: "access_group_id"
        })

      allow(UserAccessGroupRelationStore.persist(any()), return: {:ok, "success"})

      %{association_event: association_event}
    end

    test "should persist to the UserAccessGroupRelationStore when an event is received", %{
      association_event: association_event
    } do
      result =
        EventHandler.handle_event(
          Brook.Event.new(
            type: user_access_group_associate(),
            data: association_event,
            author: :author
          )
        )

      expected_assoc_event = %Raptor.Schemas.UserAccessGroupRelation{
        user_id: "user_id",
        access_group_id: "access_group_id"
      }

      assert_called(UserAccessGroupRelationStore.persist(expected_assoc_event))
      assert result == :discard
    end
  end

  describe "handle_event/1 dataset_access_group_associate" do
    setup do
      {:ok, association_event} =
        SmartCity.DatasetAccessGroupRelation.new(%{
          dataset_id: "dataset_id",
          access_group_id: "access_group_id"
        })

      allow(DatasetAccessGroupRelationStore.persist(any()), return: {:ok, "success"})

      %{association_event: association_event}
    end

    test "should persist to the DatasetAccessGroupRelationStore when an event is received", %{
      association_event: association_event
    } do
      result =
        EventHandler.handle_event(
          Brook.Event.new(
            type: dataset_access_group_associate(),
            data: association_event,
            author: :author
          )
        )

      expected_assoc_event = %Raptor.Schemas.DatasetAccessGroupRelation{
        dataset_id: "dataset_id",
        access_group_id: "access_group_id"
      }

      assert_called(DatasetAccessGroupRelationStore.persist(expected_assoc_event))
      assert result == :discard
    end
  end

  describe "handle_event/1 user_organization_associate" do
    setup do
      {:ok, association_event} =
        SmartCity.UserOrganizationAssociate.new(%{
          subject_id: "user_id",
          org_id: "org_id",
          email: "blah@example.com"
        })

      allow(UserOrgAssocStore.persist(any()), return: {:ok, "success"})

      %{association_event: association_event}
    end

    test "should persist to the UserOrgAssocStore when an event is received", %{
      association_event: association_event
    } do
      result =
        EventHandler.handle_event(
          Brook.Event.new(
            type: user_organization_associate(),
            data: association_event,
            author: :author
          )
        )

      expected_assoc_event = %UserOrgAssoc{
        user_id: "user_id",
        org_id: "org_id",
        email: "blah@example.com"
      }

      assert_called(UserOrgAssocStore.persist(expected_assoc_event))
      assert result == :discard
    end
  end

  describe "handle_event/1 user_access_group_disassociate" do
    setup do
      {:ok, disassociation_event} =
        SmartCity.UserAccessGroupRelation.new(%{
          subject_id: "subject_id",
          access_group_id: "group_id"
        })

      allow(UserAccessGroupRelationStore.delete(any()), return: {:ok, "success"})
      %{disassociation_event: disassociation_event}
    end

    test "should delete an entry from the UserAccessGroupRelationStore when an event is received",
         %{
           disassociation_event: disassociation_event
         } do
      result =
        EventHandler.handle_event(
          Brook.Event.new(
            type: user_access_group_disassociate(),
            data: disassociation_event,
            author: :author
          )
        )

      expected_disassoc_event = %Raptor.Schemas.UserAccessGroupRelation{
        user_id: "subject_id",
        access_group_id: "group_id"
      }

      assert_called(UserAccessGroupRelationStore.delete(expected_disassoc_event))
      assert result == :discard
    end
  end

  describe "handle_event/1 dataset_access_group_disassociate" do
    setup do
      {:ok, disassociation_event} =
        SmartCity.DatasetAccessGroupRelation.new(%{
          dataset_id: "dataset_id",
          access_group_id: "group_id"
        })

      allow(DatasetAccessGroupRelationStore.delete(any()), return: {:ok, "success"})
      %{disassociation_event: disassociation_event}
    end

    test "should delete an entry from the DatasetAccessGroupRelationStore when an event is received",
         %{
           disassociation_event: disassociation_event
         } do
      result =
        EventHandler.handle_event(
          Brook.Event.new(
            type: dataset_access_group_disassociate(),
            data: disassociation_event,
            author: :author
          )
        )

      expected_disassoc_event = %Raptor.Schemas.DatasetAccessGroupRelation{
        dataset_id: "dataset_id",
        access_group_id: "group_id"
      }

      assert_called(DatasetAccessGroupRelationStore.delete(expected_disassoc_event))
      assert result == :discard
    end
  end

  describe "handle_event/1 user_organization_disassociate" do
    setup do
      {:ok, disassociation_event} =
        SmartCity.UserOrganizationDisassociate.new(%{subject_id: "subject_id", org_id: "org_id"})

      allow(UserOrgAssocStore.delete(any()), return: {:ok, "success"})
      %{disassociation_event: disassociation_event}
    end

    test "should delete an entry from the UserOrgAssocStore when an event is received", %{
      disassociation_event: disassociation_event
    } do
      result =
        EventHandler.handle_event(
          Brook.Event.new(
            type: user_organization_disassociate(),
            data: disassociation_event,
            author: :author
          )
        )

      expected_disassoc_event = %UserOrgAssoc{
        user_id: "subject_id",
        org_id: "org_id",
        email: nil
      }

      assert_called(UserOrgAssocStore.delete(expected_disassoc_event))
      assert result == :discard
    end
  end

  describe "handle_event/1 dataset_update" do
    setup do
      dataset = TDG.create_dataset(%{})
      allow(DatasetStore.persist(any()), return: {:ok, "success"})
      %{dataset: dataset}
    end

    test "should persist an entry to the DatasetStore when an event is received", %{
      dataset: dataset
    } do
      result =
        EventHandler.handle_event(
          Brook.Event.new(
            type: dataset_update(),
            data: dataset,
            author: :author
          )
        )

      expected_dataset_entry = %Dataset{
        dataset_id: dataset.id,
        org_id: dataset.technical.orgId,
        system_name: dataset.technical.systemName,
        is_private: dataset.technical.private
      }

      assert_called(DatasetStore.persist(expected_dataset_entry))
      assert result == :discard
    end
  end
end
