defmodule Andi.Harvest.Harvester do
  @moduledoc """
  retreives data json and maps it to a smartcity dataset
  """
  use Tesla

  import Andi
  import SmartCity.Event, only: [dataset_harvest_end: 0]

  alias Andi.Harvest.DataJsonToDataset
  alias Andi.InputSchemas.Datasets

  require Logger

  def start_harvesting(org) do
    url = org.dataJsonUrl

    with {:ok, data_json} <- get_data_json(url),
         {:ok, decoded_data_json} <- Jason.decode(data_json),
         datasets <- map_data_json_to_dataset(decoded_data_json, org),
         :ok <- dataset_update(datasets) do
      :ok
    else
      error ->
        {:error, error}
    end
  end

  def get_data_json(url) do
    case get(url) do
      {:ok, response} ->
        {:ok, response.body}

      {:error, error} ->
        Logger.error("Failed to get data json from #{url}: #{inspect(error)}")
        {:error, error}
    end
  end

  def map_data_json_to_dataset(data_json, org) do
    DataJsonToDataset.mapper(data_json, org)
  end

  def dataset_update(datasets) do
    Enum.each(datasets, fn dataset ->
      Brook.Event.send(instance_name(), dataset_harvest_end(), :andi, dataset)
    end)
  end
end
