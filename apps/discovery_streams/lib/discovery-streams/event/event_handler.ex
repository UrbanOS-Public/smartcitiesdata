defmodule DiscoveryStreams.Event.EventHandler do
  @moduledoc """
    Event Stream Event Handler
  """
  alias SmartCity.Dataset
  use Brook.Event.Handler
  import SmartCity.Event, only: [data_ingest_start: 0, dataset_update: 0, dataset_delete: 0]
  require Logger

  def handle_event(%Brook.Event{
        type: data_ingest_start(),
        data: %Dataset{id: id, technical: %{sourceType: "stream", systemName: system_name}} = dataset,
        author: author
      }) do
    add_event_count(data_ingest_start(), author, id)

    save_dataset_to_viewstate(id, system_name)
    DiscoveryStreams.Stream.Supervisor.start_child(dataset.id)
    :ok
  end

  def handle_event(%Brook.Event{
        type: dataset_update(),
        data: %Dataset{technical: %{private: true}} = dataset,
        author: author
      }) do
    add_event_count(dataset_update(), author, dataset.id)

    DiscoveryStreams.Stream.Supervisor.terminate_child(dataset.id)

    :ok
  end

  def handle_event(%Brook.Event{
        type: dataset_update(),
        data: %Dataset{id: id, technical: %{sourceType: source_type, systemName: system_name}} = dataset,
        author: author
      })
      when source_type != "stream" do
    add_event_count(dataset_update(), author, id)

    delete_from_viewstate(id, system_name)
    DiscoveryStreams.Stream.Supervisor.terminate_child(dataset.id)

    :ok
  end

  def handle_event(%Brook.Event{
        type: dataset_delete(),
        data: %Dataset{id: id, technical: %{systemName: system_name}} = dataset,
        author: author
      }) do
    add_event_count(dataset_delete(), author, id)

    delete_from_viewstate(id, system_name)
    DiscoveryStreams.Stream.Supervisor.terminate_child(dataset.id)
    DiscoveryStreams.TopicHelper.delete_input_topic(id)
  end

  def save_dataset_to_viewstate(id, system_name) do
    Logger.debug("#{__MODULE__}: Handling Datatset: #{id} with system_name: #{system_name}")

    create(:streaming_datasets_by_id, id, system_name)
    create(:streaming_datasets_by_system_name, system_name, id)
  end

  defp delete_from_viewstate(id, system_name) do
    Logger.debug("#{__MODULE__}: Deleting Datatset: #{id} with system_name: #{system_name}")
    delete(:streaming_datasets_by_id, id)
    delete(:streaming_datasets_by_system_name, system_name)
  end

  defp add_event_count(event_type, author, dataset_id) do
    [
      app: "discovery_streams",
      author: author,
      dataset_id: dataset_id,
      event_type: event_type
    ]
    |> TelemetryEvent.add_event_metrics([:events_handled])
  end
end
