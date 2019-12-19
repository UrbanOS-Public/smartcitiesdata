defmodule DiscoveryStreams.EventHandler do
  @moduledoc """
    Event Stream Event Handler
  """
  alias SmartCity.Dataset
  use Brook.Event.Handler
  import SmartCity.Event, only: [data_ingest_start: 0, dataset_update: 0]
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
end
