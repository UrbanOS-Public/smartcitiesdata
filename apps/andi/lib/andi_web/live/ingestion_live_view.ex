defmodule AndiWeb.IngestionLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView

  import Ecto.Query, only: [from: 2]

  alias AndiWeb.IngestionLiveView.Table
  alias Andi.InputSchemas.Ingestion
  alias Andi.InputSchemas.Datasets.Dataset

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
        <hr class="ingestion-line">

        <%= live_component(@socket, Table, id: :ingestions_table, ingestions: @view_models, is_curator: @is_curator) %>

      </div>
    </div>
    """
  end

  def mount(_params, %{"is_curator" => is_curator} = _session, socket) do
    {:ok,
     assign(socket,
       is_curator: is_curator,
       ingestions: nil
     )}
  end

  def handle_params(_params, _uri, socket) do
    ingestions = refresh_ingestions()
    view_models = ingestions |> convert_to_view_models()

    {:noreply,
     assign(socket,
       ingestions: ingestions,
       view_models: view_models
     )}
  end

  def handle_event("add-ingestion", _, socket) do
    ingestion = Andi.InputSchemas.Ingestions.create()

    {:noreply, push_redirect(socket, to: "/ingestions/#{ingestion.id}")}
  end

  defp refresh_ingestions() do
    query =
      from(ingestion in Ingestion,
        left_join: dataset in Dataset,
        as: :dataset,
        on: dataset.id == ingestion.targetDataset,
        preload: [dataset: dataset, dataset: :business],
        select: ingestion
      )

    query
    |> Andi.Repo.all()
  end

  defp convert_to_view_models(ingestions) do
    Enum.map(ingestions, &to_view_model/1)
  end

  defp to_view_model(ingestion) do
    %{
      "id" => ingestion.id,
      "ingestion_name" => ingestion.name,
      "dataset_name" => dataset_name(ingestion),
      "status" => ingestion.submissionStatus |> Atom.to_string() |> String.capitalize()
    }
  end

  def dataset_name(%{dataset: %{business: %{dataTitle: dataTitle}}}), do: dataTitle
  def dataset_name(_ingestion), do: nil
end
