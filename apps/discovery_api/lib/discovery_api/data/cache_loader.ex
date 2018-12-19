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

    def load_cache do
      with {:ok, metadata_datasets} <-
        retrieve_datasets("#{data_lake_url()}/v1/metadata/feed"),
        {:ok, feedmgr_datasets} <-
          retrieve_datasets("#{data_lake_url()}/v1/feedmgr/feeds") do
            Cachex.put(
              :dataset_cache,
              "datasets",
              transform_datasets({metadata_datasets, feedmgr_datasets})
            )
      else
        {:error, reason} -> Logger.log(:error, reason)
      end
    end

  defp retrieve_datasets(url) do
    with {:ok, %HTTPoison.Response{body: body, status_code: 200}} <-
           HTTPoison.get(url, Authorization: "Basic #{data_lake_auth_string()}"),
         {:ok, decode} <- Poison.decode(body) do
          {:ok, decode}
    else
      _ -> {:error, "There was a problem processing your request"}
    end
  end

  defp transform_datasets({metadata_datasets, feedmgr_datasets}) do
    sorted_metadata_dataset = Enum.sort_by metadata_datasets, &Map.fetch(&1, "id")
    sorted_feedmgr_dataset = Enum.sort_by feedmgr_datasets["data"], &Map.fetch(&1, "id")
    Enum.zip(sorted_metadata_dataset, sorted_feedmgr_dataset)
    |> Enum.map(&transform_dataset/1)
  end

  defp transform_dataset({metadata_dataset, feedmgr_dataset}) do
    %{
      :title => metadata_dataset["displayName"],
      :description => metadata_dataset["description"],
      :fileTypes => ["csv"],
      :id => metadata_dataset["id"],
      :modifiedTime => feedmgr_dataset["updateDate"],
      :systemName => metadata_dataset["systemName"],
      :organization => metadata_dataset["userProperties"]["publisher.name"] |> to_string
    }
  end

  defp data_lake_url do
    Application.get_env(:discovery_api, :data_lake_url)
  end

  defp data_lake_auth_string do
    Application.get_env(:discovery_api, :data_lake_auth_string)
  end

  defp cache_refresh_interval do
    Application.get_env(:discovery_api, :cache_refresh_interval, "60_000")
    |> String.to_integer()
  end
end
