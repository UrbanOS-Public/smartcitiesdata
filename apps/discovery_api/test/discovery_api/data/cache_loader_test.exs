defmodule DiscoverApi.Data.CacheLoaderTest do
  use ExUnit.Case
  use Placebo

  setup do
    Application.put_env(:discovery_api, :data_lake_url, "http://example.com")
  end

  describe "CacheLoader" do
    test "Should make call to appropriate endpoint" do
      allow HTTPoison.get(any()), return: HttpHelper.create_response(body: data_from_kylo())
      DiscoveryApi.Data.CacheLoader.handle_info(:work, %{})

      assert_called HTTPoison.get("http://example.com/v1/metadata/feed")
    end

    test "Should put datasets into the cache" do
      allow HTTPoison.get(any()), return: HttpHelper.create_response(body: data_from_kylo())

      DiscoveryApi.Data.CacheLoader.handle_info(:work, %{})

      {:ok, datasets_from_cache} = Cachex.get(:dataset_cache, "datasets")
      assert Enum.count(datasets_from_cache) > 0
    end

    test "Cache should not be updated when error reponse from kylo" do
      expected_cache = [1,2,3]
      Cachex.put(:dataset_cache, "datasets", expected_cache)
      allow HTTPoison.get(any()), return: HttpHelper.create_response(status_code: 418)

      DiscoveryApi.Data.CacheLoader.handle_info(:work, %{})

      {:ok, actual} = Cachex.get(:dataset_cache, "datasets")
      assert actual == expected_cache
    end

    test "noreply to make gen server happy" do
      allow HTTPoison.get(any()), return: HttpHelper.create_response(body: data_from_kylo())
      state = %{:id => 123, :name => "Jalson"}

      {:noreply, new_state} = DiscoveryApi.Data.CacheLoader.handle_info(:work, state)

      assert new_state == state
    end

    test "GenServer looping logic" do
      allow HTTPoison.get(any()), return: HttpHelper.create_response(body: data_from_kylo())
      Application.put_env(:discovery_api, :cache_refresh_interval, "100")

      DiscoveryApi.Data.CacheLoader.start_link([])

      condition = fn -> called?(HTTPoison.get("http://example.com/v1/metadata/feed"), times(3)) end
      Patiently.wait_for!(
        condition,
        dwell: 100,
        max_tries: 20
      )
    end

    test "transformation" do
      allow HTTPoison.get(any()), return: HttpHelper.create_response(body: data_from_kylo())

      DiscoveryApi.Data.CacheLoader.handle_info(:work, %{})

      {:ok, datasets_from_cache} = Cachex.get(:dataset_cache, "datasets")
      first = Enum.at(datasets_from_cache, 0)
      assert first[:title] == "Swiss Franc Cotton"
      assert first[:description] == "Neque soluta architecto consequatur earum ipsam molestiae tempore at dolorem. Similique consectetur cum."
      assert first[:fileTypes] == ["csv"]
      assert first[:id] == "e4fca5cd-2ddd-46dd-9380-01e9c35c674f"
      assert first[:modifiedTime] == "2018-10-08T14:57:09.464Z"
      assert first[:systemName] == "Swiss_Franc_Cotton"

      second = Enum.at(datasets_from_cache, 1)
      assert second[:title] == "input invoice"
      assert second[:description] == "Quo aspernatur rerum voluptas natus ratione suscipit. Occaecati temporibus quibusdam fugit. Minus consequuntur adipisci. Velit molestias minus ratione expedita. Unde voluptatum distinctio officia voluptatem. Dolorem quibusdam quia et rem harum odio magni inventore."
      assert second[:fileTypes] == ["csv"]
      assert second[:id] == "57eac648-729c-44f5-89f2-d446ce2a4d68"
      assert second[:modifiedTime] == "2018-12-08T10:09:11.000Z"
      assert second[:systemName] == "input_invoice"
    end
  end

  defp data_from_kylo() do
    {:ok, body} =
      DiscoveryApi.Test.MockKyloResponse.metadata_response()
      |> Poison.decode
    body
  end

end
