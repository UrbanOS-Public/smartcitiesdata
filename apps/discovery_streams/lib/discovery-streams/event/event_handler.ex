defmodule DiscoveryStreams.Event.EventHandler do
  @moduledoc """
    Event Stream Event Handler
  """
  alias SmartCity.Dataset
  alias SmartCity.Ingestion
  use Brook.Event.Handler
  import SmartCity.Event, only: [data_ingest_start: 0, dataset_update: 0, dataset_delete: 0]
  require Logger

  @instance_name DiscoveryStreams.instance_name()
  
  defp stream_supervisor() do
    Application.get_env(:discovery_streams, :stream_supervisor, DiscoveryStreams.Stream.Supervisor)
  end
  
  defp topic_helper() do
    Application.get_env(:discovery_streams, :topic_helper, DiscoveryStreams.TopicHelper)
  end
  
  defp telemetry_event() do
    Application.get_env(:discovery_streams, :telemetry_event, TelemetryEvent)
  end
  
  defp brook() do
    Application.get_env(:discovery_streams, :brook, Brook)
  end
  
  defp dead_letter() do
    Application.get_env(:discovery_streams, :dead_letter, DeadLetter)
  end

  def handle_event(%Brook.Event{
        type: data_ingest_start(),
        data: %Ingestion{targetDatasets: dataset_ids} = data,
        author: author
      }) do
    Logger.info("Ingestion: #{data.id} - Received data_ingest_start event from #{author}")

    Enum.each(dataset_ids, fn dataset_id ->
      add_event_count(data_ingest_start(), author, dataset_id)
      dataset_name = brook().get!(@instance_name, :streaming_datasets_by_id, dataset_id)

      if dataset_name != nil do
        stream_supervisor().start_child(dataset_id)
      end
    end)

    :ok
  rescue
    error ->
      Logger.error("data_ingest_start failed to process: #{inspect(error)}")
      dead_letter().process(dataset_ids, data.id, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{
        type: dataset_update(),
        data: %Dataset{technical: %{sourceType: "stream", systemName: system_name, private: false}} = dataset,
        author: author
      }) do
    Logger.info("Dataset: #{dataset.id} - Received dataset_update event from #{author}")

    add_event_count(dataset_update(), author, dataset.id)

    save_dataset_to_viewstate(dataset.id, system_name)
    :ok
  rescue
    error ->
      Logger.error("dataset_update failed to process: #{inspect(error)}")
      dead_letter().process([dataset.id], nil, dataset, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{
        type: dataset_update(),
        data: %Dataset{technical: %{sourceType: "stream", systemName: system_name, private: true}} = dataset,
        author: author
      }) do
    Logger.info("Dataset: #{dataset.id} - Received dataset_update event from #{author}")

    add_event_count(dataset_update(), author, dataset.id)

    save_dataset_to_viewstate(dataset.id, system_name)
    stream_supervisor().terminate_child(dataset.id)
    :ok
  rescue
    error ->
      Logger.error("dataset_update failed to process: #{inspect(error)}")
      dead_letter().process([dataset.id], nil, dataset, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{
        type: dataset_delete(),
        data: %Dataset{id: id, technical: %{systemName: system_name}} = dataset,
        author: author
      }) do
    Logger.info("Dataset: #{id} - Received dataset_delete event from #{author}")

    add_event_count(dataset_delete(), author, id)

    delete_from_viewstate(id, system_name)
    stream_supervisor().terminate_child(dataset.id)
    topic_helper().delete_input_topic(id)
  rescue
    error ->
      Logger.error("dataset_delete failed to process: #{inspect(error)}")
      dead_letter().process([id], nil, dataset, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
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
    |> telemetry_event().add_event_metrics([:events_handled])
  end
end
