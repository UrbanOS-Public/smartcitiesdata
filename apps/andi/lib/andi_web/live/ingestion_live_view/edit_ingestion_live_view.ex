defmodule AndiWeb.IngestionLiveView.EditIngestionLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView
  require Logger

  @instance_name Andi.instance_name()

  import SmartCity.Event, only: [ingestion_delete: 0]

  alias Andi.InputSchemas.Ingestions
  alias Andi.Services.IngestionStore

  access_levels(render: [:private])

  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
    <div class="edit-page" id="ingestions-edit-page">
      <div class="edit-ingestion-title">
        <h2 class="component-title-text">Define Data Ingestion</h2>
      </div>

      <div class="edit-page__btn-group">
        <button id="ingestion-delete-button" class="btn btn--delete" phx-click="prompt-ingestion-delete" type="button">
          <span class="delete-icon material-icons">delete_outline</span>
          DELETE
        </button>
      </div>

      <%= live_component(@socket, AndiWeb.IngestionLiveView.DeleteIngestionModal, visibility: @delete_ingestion_modal_visibility) %>
    </div>
    """
  end

  def mount(_params, %{"is_curator" => is_curator, "ingestion" => ingestion} = _session, socket) do
    {:ok,
     assign(socket,
       is_curator: is_curator,
       ingestion: ingestion,
       delete_ingestion_modal_visibility: "hidden"
     )}
  end

  def handle_event("prompt-ingestion-delete", _, socket) do
    {:noreply, assign(socket, delete_ingestion_modal_visibility: "visible")}
  end

  def handle_event("delete-confirmed", _, socket) do
    ingestion_id = socket.assigns.ingestion.id

    case IngestionStore.get(ingestion_id) do
      {:ok, nil} ->
        Ingestions.delete(ingestion_id)
        {:noreply, redirect(socket, to: header_ingestions_path())}

      {:ok, smrt_ingestion} ->
        # TODO: Add AuditEvents back in
        # Andi.Schemas.AuditEvents.log_audit_event(user_id, ingestion_delete(), smrt_ingestion)
        Brook.Event.send(@instance_name, ingestion_delete(), :andi, smrt_ingestion)
    end

    # TODO: Sometimes the redirect reflects old state? (doesn't indicate that ingestion was deleted till refresh)
    {:noreply, redirect(socket, to: header_ingestions_path())}
  end

  def handle_event("delete-canceled", _, socket) do
    {:noreply, assign(socket, delete_ingestion_modal_visibility: "hidden")}
  end
end
