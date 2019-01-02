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
    with {:ok, %{"data" => feed_list}} <- retrieve_datasets("#{data_lake_url()}/v1/feedmgr/feeds") do
      feed_details = get_feed_details(feed_list)

      Cachex.put(
        :dataset_cache,
        "datasets",
        transform_datasets(feed_details)
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

  def get_feed_details(feedmgr_dataset) do
    feedmgr_dataset
    |> Enum.map(fn dataset ->
      case retrieve_datasets("#{data_lake_url()}/v1/feedmgr/feeds/#{dataset["id"]}") do
        {:ok, cooldata} -> cooldata
        _ -> %{}
      end
    end)
  end

  defp transform_datasets(feed_details) do
    feed_details
    |> Enum.map(&transform_dataset/1)
  end

  defp transform_dataset(feed_details) do
    %{
      title: feed_details["feedName"],
      description: feed_details["description"],
      fileTypes: ["csv"],
      id: feed_details["id"],
      modifiedTime: feed_details["updateDate"],
      systemName: feed_details["systemFeedName"],
      organization: (feed_details["userProperties"] || []) |> get_organization(),
      tags: (feed_details["tags"] || []) |> get_tags()
    }
  end

  defp get_tags(dataset_tags) do
    dataset_tags
    |> Enum.map(fn item -> item["name"] end)
  end

  defp get_organization(user_properties) do
    user_properties
    |> Enum.find_value("", &extract_organization_if_found/1)
  end

  defp extract_organization_if_found(user_property) do
    case user_property["systemName"] do
      "publisher.name" -> user_property["value"]
      _ -> false
    end
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
