defmodule Raptor.Event.EventHandler do
  @moduledoc "Event Handler for event stream"

  use Brook.Event.Handler

  alias Raptor.Services.DatasetStore
  alias Raptor.Services.UserOrgAssocStore
  alias Raptor.UserOrgAssoc
  alias Raptor.Schemas.Dataset

  import SmartCity.Event,
    only: [
      dataset_update: 0,
      user_organization_associate: 0,
      user_organization_disassociate: 0
    ]

  alias SmartCity.{UserOrganizationAssociate, UserOrganizationDisassociate, Dataset}

  def handle_event(%Brook.Event{
        type: dataset_update(),
        author: _author,
        data: %Dataset{} = dataset
      }) do
    {:ok, dataset} = Raptor.Schemas.Dataset.from_event(dataset)
    DatasetStore.persist(dataset)
    :discard
  end

  def handle_event(
        %Brook.Event{
          type: user_organization_associate(),
          data: %UserOrganizationAssociate{} = association,
          author: _author
        }
      ) do
    {:ok, user_org_assoc} = UserOrgAssoc.from_associate_event(association)
    UserOrgAssocStore.persist(user_org_assoc)
    :discard
  end

  def handle_event(
        %Brook.Event{
          type: user_organization_disassociate(),
          data: %UserOrganizationDisassociate{} = disassociation,
          author: _author
        }
      ) do
    {:ok, user_org_assoc} = UserOrgAssoc.from_disassociate_event(disassociation)
    UserOrgAssocStore.delete(user_org_assoc)
    :discard
  end
end
