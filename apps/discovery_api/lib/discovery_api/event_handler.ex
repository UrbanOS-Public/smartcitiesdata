defmodule DiscoveryApi.EventHandler do
  @moduledoc "Event Handler for event stream"
  use Brook.Event.Handler
  import SmartCity.Event, only: [organization_update: 0]
  alias SmartCity.Organization
  alias DiscoveryApi.Schemas.Organizations

  def handle_event(%Brook.Event{type: organization_update(), data: %Organization{} = data}) do
    Organizations.create_or_update(data)
    :discard
  end
end
