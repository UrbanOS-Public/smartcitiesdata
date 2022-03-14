defmodule AndiWeb.IngestionLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView

  access_levels(render: [:private])

  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
    <div class="ingestions-view">
      <div class="ingestions-index">
        <div class="ingestions-index__header">
          <h1 class="ingestions-index__title">All Data Ingestions</h1>
          <button type="button" class="btn btn--add-ingestion btn--action" phx-click="add-ingestion">ADD DATA INGESTION</button>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, %{"is_curator" => is_curator} = _session, socket) do
    {:ok,
     assign(socket,
       is_curator: is_curator
     )}
  end

  def handle_event("add-ingestion", _, socket) do
    ingestion = Andi.InputSchemas.Ingestions.create()
    IO.inspect(ingestion, label: "HERE")

    {:noreply, push_redirect(socket, to: "/ingestions/#{ingestion.id}")}
  end
end
