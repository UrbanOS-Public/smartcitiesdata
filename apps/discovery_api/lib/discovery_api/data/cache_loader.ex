require Logger

defmodule DiscoveryApi.Data.CacheLoader do
  use GenServer

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    load_cache()
    schedule_work()
    {:ok, nil}
  end

  defp schedule_work() do
    Process.send_after(self(), :work, cache_refresh_interval())
  end

  def handle_info(:work, state) do
    load_cache()
    schedule_work()
    {:noreply, state}
  end

  @spec load_cache() :: :ok | {:error, any()} | {:ok, boolean()}
  def load_cache do
    case retrieve_datasets("#{data_lake_url()}/v1/metadata/feed") do
      {:ok, response} -> Cachex.put(:dataset_cache, "datasets", response)
      {:error, reason} -> Logger.log(:error, reason)
    end
  end

  defp retrieve_datasets(url) do
    with {:ok, %HTTPoison.Response{body: body, status_code: 200}} <- HTTPoison.get(url),
         {:ok, decode} <- Poison.decode(body) do
      {:ok, transform_datasets(decode)}
    else
      _ -> {:error, "There was a problem processing your request"}
    end
  end

  defp transform_datasets(datasets) do
    Enum.map(datasets, &transform_dataset/1)
  end

  defp transform_dataset(dataset) do
    %{
      "title" => dataset["displayName"],
      "description" => dataset["description"],
      "fileTypes" => ["csv"],
      "id" => dataset["id"],
      "modifiedTime" => dataset["modifiedTime"],
      "systemName" => dataset["systemName"]
    }
  end

  defp data_lake_url do
    Application.get_env(:discovery_api, :data_lake_url)
  end

  defp cache_refresh_interval do
    Application.get_env(:discovery_api, :cache_refresh_interval, "60_000")
    |> String.to_integer()
  end
end
