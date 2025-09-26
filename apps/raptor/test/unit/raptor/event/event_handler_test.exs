defmodule Raptor.Event.EventHandlerTest do
  use ExUnit.Case
  import Mock

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
    test "should persist to the UserAccessGroupRelationStore when an event is received" do
      {:ok, association_event} =
        SmartCity.UserAccessGroupRelation.new(%{
          subject_id: "user_id",
          access_group_id: "access_group_id"
        })

      expected_assoc_event = %Raptor.Schemas.UserAccessGroupRelation{
        user_id: "user_id",
        access_group_id: "access_group_id"
      }

      with_mock UserAccessGroupRelationStore, persist: fn _ -> {:ok, "success"} end do
        result =
          EventHandler.handle_event(
            Brook.Event.new(
              type: user_access_group_associate(),
              data: association_event,
              author: :author
            )
          )

        assert called(UserAccessGroupRelationStore.persist(expected_assoc_event))
        assert result == :discard
      end
    end
  end

  describe "handle_event/1 dataset_access_group_associate" do
    test "should persist to the DatasetAccessGroupRelationStore when an event is received" do
      {:ok, association_event} =
        SmartCity.DatasetAccessGroupRelation.new(%{
          dataset_id: "dataset_id",
          access_group_id: "access_group_id"
        })

      expected_assoc_event = %Raptor.Schemas.DatasetAccessGroupRelation{
        dataset_id: "dataset_id",
        access_group_id: "access_group_id"
      }

      with_mock DatasetAccessGroupRelationStore, persist: fn _ -> {:ok, "success"} end do
        result =
          EventHandler.handle_event(
            Brook.Event.new(
              type: dataset_access_group_associate(),
              data: association_event,
              author: :author
            )
          )

        assert called(DatasetAccessGroupRelationStore.persist(expected_assoc_event))
        assert result == :discard
      end
    end
  end

  describe "handle_event/1 user_organization_associate" do
    test "should persist to the UserOrgAssocStore when an event is received" do
      {:ok, association_event} =
        SmartCity.UserOrganizationAssociate.new(%{
          subject_id: "user_id",
          org_id: "org_id",
          email: "blah@example.com"
        })

      expected_assoc_event = %UserOrgAssoc{
        user_id: "user_id",
        org_id: "org_id",
        email: "blah@example.com"
      }

      with_mock UserOrgAssocStore, persist: fn _ -> {:ok, "success"} end do
        result =
          EventHandler.handle_event(
            Brook.Event.new(
              type: user_organization_associate(),
              data: association_event,
              author: :author
            )
          )

        assert called(UserOrgAssocStore.persist(expected_assoc_event))
        assert result == :discard
      end
    end
  end

  describe "handle_event/1 user_access_group_disassociate" do
    test "should delete an entry from the UserAccessGroupRelationStore when an event is received" do
      {:ok, disassociation_event} =
        SmartCity.UserAccessGroupRelation.new(%{
          subject_id: "subject_id",
          access_group_id: "group_id"
        })

      expected_disassoc_event = %Raptor.Schemas.UserAccessGroupRelation{
        user_id: "subject_id",
        access_group_id: "group_id"
      }

      with_mock UserAccessGroupRelationStore, delete: fn _ -> {:ok, "success"} end do
        result =
          EventHandler.handle_event(
            Brook.Event.new(
              type: user_access_group_disassociate(),
              data: disassociation_event,
              author: :author
            )
          )

        assert called(UserAccessGroupRelationStore.delete(expected_disassoc_event))
        assert result == :discard
      end
    end
  end

  describe "handle_event/1 dataset_access_group_disassociate" do
    test "should delete an entry from the DatasetAccessGroupRelationStore when an event is received" do
      {:ok, disassociation_event} =
        SmartCity.DatasetAccessGroupRelation.new(%{
          dataset_id: "dataset_id",
          access_group_id: "group_id"
        })

      expected_disassoc_event = %Raptor.Schemas.DatasetAccessGroupRelation{
        dataset_id: "dataset_id",
        access_group_id: "group_id"
      }

      with_mock DatasetAccessGroupRelationStore, delete: fn _ -> {:ok, "success"} end do
        result =
          EventHandler.handle_event(
            Brook.Event.new(
              type: dataset_access_group_disassociate(),
              data: disassociation_event,
              author: :author
            )
          )

        assert called(DatasetAccessGroupRelationStore.delete(expected_disassoc_event))
        assert result == :discard
      end
    end
  end

  describe "handle_event/1 user_organization_disassociate" do
    test "should delete an entry from the UserOrgAssocStore when an event is received" do
      {:ok, disassociation_event} =
        SmartCity.UserOrganizationDisassociate.new(%{subject_id: "subject_id", org_id: "org_id"})

      expected_disassoc_event = %UserOrgAssoc{
        user_id: "subject_id",
        org_id: "org_id",
        email: nil
      }

      with_mock UserOrgAssocStore, delete: fn _ -> {:ok, "success"} end do
        result =
          EventHandler.handle_event(
            Brook.Event.new(
              type: user_organization_disassociate(),
              data: disassociation_event,
              author: :author
            )
          )

        assert called(UserOrgAssocStore.delete(expected_disassoc_event))
        assert result == :discard
      end
    end
  end

  describe "handle_event/1 dataset_update" do
    test "should persist an entry to the DatasetStore when an event is received" do
      dataset = TDG.create_dataset(%{})

      expected_dataset_entry = %Dataset{
        dataset_id: dataset.id,
        org_id: dataset.technical.orgId,
        system_name: dataset.technical.systemName,
        is_private: dataset.technical.private
      }

      with_mock DatasetStore, persist: fn _ -> {:ok, "success"} end do
        result =
          EventHandler.handle_event(
            Brook.Event.new(
              type: dataset_update(),
              data: dataset,
              author: :author
            )
          )

        assert called(DatasetStore.persist(expected_dataset_entry))
        assert result == :discard
      end
    end
  end
end
