defmodule Alchemist.Event.EventHandler do
  @moduledoc "Event Handler for event stream"

  use Brook.Event.Handler

  import SmartCity.Event,
    only: [
      organization_update: 0,
      user_organization_associate: 0,
      user_organization_disassociate: 0
    ]

  alias SmartCity.{UserOrganizationAssociate, UserOrganizationDisassociate, Organization}

  @instance_name Alchemist.instance_name()

  def handle_event(%Brook.Event{
        type: organization_update(),
        data: %Organization{} = data,
        author: author
      }) do
    IO.inspect(data, label: "I received this event")
    :discard
  end

  def handle_event(
        %Brook.Event{
          type: user_organization_associate(),
          data: %UserOrganizationAssociate{} = association,
          author: author
        } = event
      ) do
    :discard
  end

  def handle_event(
        %Brook.Event{
          type: user_organization_disassociate(),
          data: %UserOrganizationDisassociate{} = disassociation,
          author: author
        } = event
      ) do
    :discard
  end
end
