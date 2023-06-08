defmodule Raptor.Event.EventHandler do
  @moduledoc "Event Handler for event stream"

  use Brook.Event.Handler

  alias Raptor.Services.DatasetStore
  alias Raptor.Services.UserOrgAssocStore
  alias Raptor.Schemas.UserOrgAssoc
  alias Raptor.Schemas.Dataset
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

  alias SmartCity.{
    UserOrganizationAssociate,
    UserOrganizationDisassociate,
    Dataset,
    UserAccessGroupRelation,
    DatasetAccessGroupRelation
  }

  def handle_event(%Brook.Event{
        type: dataset_update(),
        author: author,
        data: %Dataset{} = dataset
      }) do
    Logger.info("Dataset #{dataset.id} - Received dataset_update event from #{author}")

    {:ok, dataset} = Raptor.Schemas.Dataset.from_event(dataset)
    DatasetStore.persist(dataset)
    :discard
  end

  def handle_event(%Brook.Event{
        type: user_organization_associate(),
        data: %UserOrganizationAssociate{} = association,
        author: author
      }) do
    Logger.info("User: #{association.subject_id}; Organization: #{association.org_id} - Received user_organization_associate event from #{author}")

    {:ok, user_org_assoc} = UserOrgAssoc.from_associate_event(association)
    UserOrgAssocStore.persist(user_org_assoc)
    :discard
  end

  def handle_event(%Brook.Event{
        type: user_organization_disassociate(),
        data: %UserOrganizationDisassociate{} = disassociation,
        author: author
      }) do
    Logger.info("User: #{disassociation.subject_id}; Organization: #{disassociation.org_id} - Received user_organization_disassociate event from #{author}")

    {:ok, user_org_assoc} = UserOrgAssoc.from_disassociate_event(disassociation)
    UserOrgAssocStore.delete(user_org_assoc)
    :discard
  end

  def handle_event(%Brook.Event{
        type: user_access_group_associate(),
        data: %UserAccessGroupRelation{} = association,
        author: author
      }) do
    Logger.info("User: #{association.subject_id}; Access Group: #{association.access_group_id} - Received user_access_group_associate event from #{author}")

    {:ok, user_access_group_assoc} =
      Raptor.Schemas.UserAccessGroupRelation.from_smrt_relation(association)

    UserAccessGroupRelationStore.persist(user_access_group_assoc)
    :discard
  end

  def handle_event(%Brook.Event{
        type: user_access_group_disassociate(),
        data: %UserAccessGroupRelation{} = disassociation,
        author: author
      }) do
    Logger.info("User: #{disassociation.subject_id}; Access Group: #{disassociation.access_group_id} - Received user_access_group_associate event from #{author}")

    {:ok, user_access_group_disassoc} =
      Raptor.Schemas.UserAccessGroupRelation.from_smrt_relation(disassociation)

    UserAccessGroupRelationStore.delete(user_access_group_disassoc)
    :discard
  end

  def handle_event(%Brook.Event{
        type: dataset_access_group_associate(),
        data: %DatasetAccessGroupRelation{} = association,
        author: author
      }) do
    Logger.info("Dataset: #{association.dataset_id}; Access Group: #{association.access_group_id} - Received dataset_access_group_associate event from #{author}")

    {:ok, dataset_access_group_assoc} =
      Raptor.Schemas.DatasetAccessGroupRelation.from_smrt_relation(association)

    DatasetAccessGroupRelationStore.persist(dataset_access_group_assoc)
    :discard
  end

  def handle_event(%Brook.Event{
        type: dataset_access_group_disassociate(),
        data: %DatasetAccessGroupRelation{} = disassociation,
        author: author
      }) do
    Logger.info("Dataset: #{association.dataset_id}; Access Group: #{association.access_group_id} - Received dataset_access_group_disassociate event from #{author}")

    {:ok, dataset_access_group_disassoc} =
      Raptor.Schemas.DatasetAccessGroupRelation.from_smrt_relation(disassociation)

    DatasetAccessGroupRelationStore.delete(dataset_access_group_disassoc)
    :discard
  end
end
