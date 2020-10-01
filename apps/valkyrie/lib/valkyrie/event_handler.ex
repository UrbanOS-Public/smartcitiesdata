defmodule Valkyrie.EventHandler do
  @moduledoc """
  Event Stream Event Handler
  """
  alias SmartCity.Dataset
  use Brook.Event.Handler
  import SmartCity.Event, only: [data_ingest_start: 0, data_standardization_end: 0, dataset_delete: 0]
  require Logger

  def handle_event(%Brook.Event{type: data_ingest_start(), data: %Dataset{id: id, technical: %{sourceType: source_type, schema: schema}}, author: author})
    when source_type in ["ingest", "stream"] do
    add_event_count(data_ingest_start(), author, id)

    save_dataset_to_viewstate(id, schema)
    begin_dataset(id)

    :ok
  end

  def handle_event(%Brook.Event{type: data_standardization_end(), data: %{"dataset_id" => id}, author: author
}) do
    add_event_count(data_standardization_end(), author, id)

    delete_from_viewstate(id)
    end_dataset(id)

    :ok
  end

  def handle_event(%Brook.Event{type: dataset_delete(), data: %Dataset{id: id}, author: author}) do
    add_event_count(dataset_delete(), author, id)

    delete_from_viewstate(id)
    end_dataset(id)

    :ok
  end

  defp begin_dataset(id) do
    Logger.debug("#{__MODULE__}: Beginning Ingestion for Dataset: #{id}")
    Valkyrie.Stream.Supervisor.start_child(id)
  end

  defp end_dataset(id) do
    Logger.debug("#{__MODULE__}: Ending Ingestion for Dataset: #{id}")
    Valkyrie.Stream.Supervisor.terminate_child(id)
    Valkyrie.TopicHelper.delete_topics(id)
  end

  def save_dataset_to_viewstate(id, schema) do
    Logger.debug("#{__MODULE__}: Handling Datatset: #{id} with schema #{inspect(schema)}")
    create(:datasets_by_id, id, schema)
  end

  defp delete_from_viewstate(id) do
    Logger.debug("#{__MODULE__}: Deleting Datatset: #{id}")
    delete(:datasets_by_id, id)
  end

  defp add_event_count(event_type, author, dataset_id) do
    [
      app: "valkyrie",
      author: author,
      dataset_id: dataset_id,
      event_type: event_type
    ]
    |> TelemetryEvent.add_event_metrics([:events_handled])
  end
end
