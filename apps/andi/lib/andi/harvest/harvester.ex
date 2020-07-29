defmodule Andi.Harvest.Harvester do
  @moduledoc """
  retreives data json and maps it to a smartcity dataset
  """
  use Tesla

  import Andi
  import SmartCity.Event, only: [dataset_update: 0]

  alias Andi.Harvest.DataJsonToDataset

  require Logger

  plug Tesla.Middleware.JSON

  def start_harvesting(org) do
    url = org.dataJsonUrl
    with {:ok, data_json} <- get_data_json(url),
         datasets <- map_data_json_to_dataset(data_json, org),
         :ok <- dataset_update(datasets) do
           :ok
    else
      error ->
        {:error, error}
    end
  end

  def get_data_json(url) do
    with {:ok, response} <- get(url),
         {:ok, body} <- Jason.decode(response.body) do
      {:ok, body}
    else
      error ->
        Logger.error("Failed to get data json from #{url}: #{inspect(error)}")
        {:error, error}
    end
  end

  def map_data_json_to_dataset(data_json, org) do
    DataJsonToDataset.mapper(data_json, org)
  end

  def dataset_update(datasets) do
    Enum.each(datasets, &Brook.Event.send(instance_name(), dataset_update(), :andi, &1))
  end
end
