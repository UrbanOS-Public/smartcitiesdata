defmodule Andi.EventHandler do
  @moduledoc "Event Handler for event stream"
  use Brook.Event.Handler
  require Logger
  alias SmartCity.{Dataset, Organization}
  import SmartCity.Event, only: [dataset_update: 0, organization_update: 0]

  def handle_event(%Brook.Event{type: dataset_update(), data: %Dataset{} = data}) do
    {:merge, :dataset, data.id, data}
  end

  def handle_event(%Brook.Event{type: organization_update(), data: %Organization{} = data}) do
    {:merge, :org, data.id, data}
  end
end
