defmodule Andi.Harvest.Harvester do
  @moduledoc """
  retreives data json and maps it to a smartcity dataset
  """
  use Tesla

  import Andi
  import SmartCity.Event, only: [dataset_harvest_end: 0, dataset_harvest_start: 0, dataset_update: 0]
  alias SmartCity.Organization

  alias Andi.Harvest.DataJsonDatasetMapper
  alias Andi.InputSchemas.Organizations
  alias Andi.Services.OrgStore

  require Logger

  def start_harvesting(%Organization{} = org) do
    url = org.dataJsonUrl

    with {:ok, data_json} <- get_data_json(url),
         {:ok, decoded_data_json} <- Jason.decode(data_json),
         datasets <- map_data_json_to_dataset(decoded_data_json, org),
         harvested_datasets <- map_data_json_to_harvested_dataset(decoded_data_json, org),
         :ok <- harvested_dataset_update(harvested_datasets),
         :ok <- dataset_update(datasets) do
      :ok
    else
      error ->
        {:error, error}
    end
  end

  def start_harvesting() do
    case OrgStore.get_all() do
      {:ok, orgs} ->
        orgs
        |> Enum.filter(fn org -> org.dataJsonUrl != nil end)
        |> Enum.each(fn org -> Brook.Event.send(instance_name(), dataset_harvest_start(), :andi, org) end)

      _ ->
        Logger.info("No Orgs with data JSON to harvest")
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
    DataJsonDatasetMapper.dataset_mapper(data_json, org)
  end

  def map_data_json_to_harvested_dataset(data_json, org) do
    DataJsonDatasetMapper.harvested_dataset_mapper(data_json, org)
  end

  def dataset_update(datasets) do
    Enum.each(datasets, fn dataset ->
      case Organizations.get_harvested_dataset(dataset.id) do
        %{include: false} -> Logger.info("Skipping dataset update for harvested dataset #{dataset.id}")
        _ -> Brook.Event.send(instance_name(), dataset_update(), :andi, dataset)
      end
    end)
  end

  def harvested_dataset_update(harvested_datasets) do
    Enum.each(harvested_datasets, fn harvested_dataset ->
      case Organizations.get_harvested_dataset(harvested_dataset["datasetId"]) do
        %{include: false} -> Logger.info("Skipping dataset update for harvested dataset #{harvested_dataset["datasetId"]}")
        _ -> Brook.Event.send(instance_name(), dataset_harvest_end(), :andi, harvested_dataset)
      end
    end)
  end
end
