defmodule Andi.Harvest.Harvester do
  @moduledoc """
  retreives data json and maps it to a smartcity dataset
  """
  use Tesla

  alias Andi.Harvest.DataJsonToDataset

  require Logger

  plug Tesla.Middleware.JSON

  def start_harvesting(org) do
    url = org.dataJsonUrl
    get_data_json(url)
    :ok
  end

  def get_data_json(url) do
    with {:ok, response} <- get(url),
         {:ok, body} <- Jason.decode(response.body) do
      body
    else
      error ->
        Logger.error("Failed to get data json from #{url}: #{inspect(error)}")
    end
  end

  def map_data_json_to_dataset(data_json) do
    DataJsonToDataset.mapper(data_json)
  end
end
