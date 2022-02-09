defmodule Alchemist.Event.EventHandler do
  @moduledoc "Event Handler for event stream"

  use Brook.Event.Handler

  import SmartCity.Event,
    only: [
      ingestion_update: 0,
      organization_update: 0,
      user_organization_associate: 0,
      user_organization_disassociate: 0
    ]

  alias SmartCity.{
    UserOrganizationAssociate,
    UserOrganizationDisassociate,
    Organization,
    Ingestion
  }

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

  def handle_event(
        %Brook.Event{
          type: ingestion_update(),
          data: %Ingestion{} = data,
          author: author
        } = event
      ) do
        # topic: event stream: ingestion update
        #                     |
        #       topic: raw       topic:  transformed
        # broadway creates that raw and transformed topic as a result of ingestion_update
        # https://github.com/UrbanOS-Public/smartcitiesdata/blob/986e0ec2605b8ec56938eb9f71f55181af12fd9b/apps/valkyrie/lib/valkyrie/event/event_handler.ex#L24
      IO.inspect(data, label: "I received this event")
      # Brook.Event.send(@instance_name, ingestion_update(), :alchemist, data)
    :discard
  end
end
