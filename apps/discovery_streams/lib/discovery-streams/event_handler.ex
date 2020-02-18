defmodule DiscoveryStreams.EventHandler do
  @moduledoc """
    Event Stream Event Handler
  """
  alias SmartCity.Dataset
  use Brook.Event.Handler
  import SmartCity.Event, only: [data_ingest_start: 0, dataset_update: 0, dataset_delete: 0]
  require Logger

  def handle_event(%Brook.Event{
        type: data_ingest_start(),
        data: %Dataset{id: id, technical: %{sourceType: "stream", private: false, systemName: system_name}}
      }) do
    save_dataset_to_viewstate(id, system_name)
    :ok
  end

  def handle_event(%Brook.Event{type: dataset_update(), data: %Dataset{technical: %{private: true}} = dataset}) do
    delete_from_viewstate(dataset.id, dataset.technical.systemName)

    :ok
  end

  def handle_event(%Brook.Event{
        type: dataset_update(),
        data: %Dataset{id: id, technical: %{sourceType: source_type, systemName: system_name}}
      })
      when source_type != "stream" do
    delete_from_viewstate(id, system_name)

    :ok
  end

  def handle_event(%Brook.Event{
        type: dataset_delete(),
        data: %Dataset{id: id, technical: %{systemName: system_name}}
      }) do
    delete_dataset_topic(id, system_name)
    delete_from_viewstate(id, system_name)
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

  defp delete_dataset_topic(id, system_name) do
    case delete_topic(id) do
      :ok ->
        Logger.debug("#{__MODULE__}: Deleted dataset for dataset id: #{id} and system name: #{system_name}")

      {:error, error} ->
        Logger.error(
          "#{__MODULE__}: Failed to delete dataset for dataset id: #{id} and system name: #{system_name}, Reason: #{
            inspect(error)
          }"
        )
    end
  end

  defp delete_topic(dataset_id) do
    Logger.debug("#{__MODULE__}: Deleting Datatset: #{dataset_id}")
    DiscoveryStreams.TopicHelper.delete_input_topic(dataset_id)
  end
end
