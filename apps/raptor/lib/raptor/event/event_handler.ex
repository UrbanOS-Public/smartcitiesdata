defmodule Raptor.Event.EventHandler do
  @moduledoc "Event Handler for event stream"

  use Brook.Event.Handler

  alias Raptor.Services.DatasetStore
  alias Raptor.Services.OrgStore
  alias Raptor.Persistence
  alias Raptor.UserOrgAssoc

  import SmartCity.Event,
    only: [
      dataset_update: 0,
      organization_update: 0,
      user_organization_associate: 0,
      user_organization_disassociate: 0
    ]

  alias SmartCity.{UserOrganizationAssociate, UserOrganizationDisassociate, Organization, Dataset}

  @instance_name Raptor.instance_name()

  def handle_event(%Brook.Event{
        type: organization_update(),
        data: %Organization{} = data,
        author: author
      }) do
    OrgStore.update(data)
    :discard
  end

  def handle_event(%Brook.Event{type: dataset_update(), author: author, data: %Dataset{} = dataset}) do
    DatasetStore.update(dataset)
    :discard
  end

  def handle_event(
        %Brook.Event{
          type: user_organization_associate(),
          data: %UserOrganizationAssociate{} = association,
          author: author
        } = event
      ) do
    {:ok, user_org_assoc} = UserOrgAssoc.from_associate_event(association)
    IO.inspect(user_org_assoc, label: "I GOT TO UPDATE")
    Persistence.persist(user_org_assoc)
    :discard
  end

  def handle_event(
        %Brook.Event{
          type: user_organization_disassociate(),
          data: %UserOrganizationDisassociate{} = disassociation,
          author: author
        } = event
      ) do
    {:ok, user_org_assoc} = UserOrgAssoc.from_disassociate_event(disassociation)
    IO.inspect(user_org_assoc, label: "I GOT TO DELETE")
    Persistence.delete(user_org_assoc)
    :discard
  end
end
