defmodule DiscoveryApi.Data.CacheLoaderTest do
  use ExUnit.Case
  use Placebo

  setup do
    Application.put_env(:discovery_api, :data_lake_url, "http://example.com")
    Application.put_env(:discovery_api, :data_lake_auth_string, "authorized")
  end

  describe "CacheLoader regular returns" do
    setup do
      allow HTTPoison.get(ends_with("/feedmgr/feeds"), any()),
        return: HttpHelper.create_response(body: feedmgr_data_from_kylo())

      allow HTTPoison.get(ends_with("/feedmgr/feeds/14fca5cd-2ddd-46dd-9380-01e9c35c674f"), any()),
        return: HttpHelper.create_response(body: feedmgr_id_data_from_kylo_without_tags())

      allow HTTPoison.get(ends_with("/feedmgr/feeds/57eac648-729c-44f5-89f2-d446ce2a4d68"), any()),
        return: HttpHelper.create_response(body: feedmgr_id_data_from_kylo_with_tags())

      :ok
    end

    test "Should make call to appropriate endpoint" do
      DiscoveryApi.Data.CacheLoader.handle_info(:work, %{})

      assert_called HTTPoison.get("http://example.com/v1/feedmgr/feeds", any())
    end

    test "Should put datasets into the cache" do
      DiscoveryApi.Data.CacheLoader.handle_info(:work, %{})

      {:ok, datasets_from_cache} = Cachex.get(:dataset_cache, "datasets")
      assert Enum.count(datasets_from_cache) > 0
    end

    test "noreply to make gen server happy" do
      state = %{:id => 123, :name => "Jalson"}

      {:noreply, new_state} = DiscoveryApi.Data.CacheLoader.handle_info(:work, state)

      assert new_state == state
    end

    test "GenServer looping logic" do
      allow HTTPoison.get(ends_with("/feeds"), any()),
        return: HttpHelper.create_response(body: feedmgr_data_from_kylo())

      Application.put_env(:discovery_api, :cache_refresh_interval, "100")

      DiscoveryApi.Data.CacheLoader.start_link([])

      condition = fn ->
        called?(HTTPoison.get("http://example.com/v1/feedmgr/feeds", Authorization: "Basic authorized"), times(3))
      end

      Patiently.wait_for!(
        condition,
        dwell: 100,
        max_tries: 20
      )
    end

    test "transformation" do
      DiscoveryApi.Data.CacheLoader.handle_info(:work, %{})

      {:ok, datasets_from_cache} = Cachex.get(:dataset_cache, "datasets")
      first = Enum.at(datasets_from_cache, 0)
      assert first[:title] == "Swiss Franc Cotton"

      assert first[:description] ==
               "Neque soluta architecto consequatur earum ipsam molestiae tempore at dolorem. Similique consectetur cum."

      assert first[:fileTypes] == ["csv"]
      assert first[:id] == "14fca5cd-2ddd-46dd-9380-01e9c35c674f"
      assert first[:modifiedTime] == "recently"
      assert first[:systemName] == "Swiss_Franc_Cotton"

      second = Enum.at(datasets_from_cache, 1)
      assert second[:title] == "input invoice"

      assert second[:description] ==
               "Quo aspernatur rerum voluptas natus ratione suscipit. Occaecati temporibus quibusdam fugit. Minus consequuntur adipisci. Velit molestias minus ratione expedita. Unde voluptatum distinctio officia voluptatem. Dolorem quibusdam quia et rem harum odio magni inventore."

      assert second[:fileTypes] == ["csv"]
      assert second[:id] == "57eac648-729c-44f5-89f2-d446ce2a4d68"
      assert second[:modifiedTime] == "a while back"
      assert second[:systemName] == "input_invoice"
      assert second[:organization] == "Slime Jime"
      assert second[:tags] == ["bar", "foo"]
    end
  end

  describe "CacheLoader error return" do
    test "Cache should not be updated when error reponse from kylo" do
      expected_cache = [1, 2, 3]
      Cachex.put(:dataset_cache, "datasets", expected_cache)

      allow HTTPoison.get(any(), any()), return: HttpHelper.create_response(status_code: 418)

      DiscoveryApi.Data.CacheLoader.handle_info(:work, %{})

      {:ok, actual} = Cachex.get(:dataset_cache, "datasets")
      assert actual == expected_cache
    end
  end

  defp feedmgr_data_from_kylo() do
    {:ok, body} =
      DiscoveryApi.Test.MockKyloResponse.feedmgr_response()
      |> Poison.decode()

    body
  end

  defp feedmgr_id_data_from_kylo_with_tags() do
    {:ok, body} =
      DiscoveryApi.Test.MockKyloResponse.feedmgr_id_response_with_tags()
      |> Poison.decode()

    body
  end

  defp feedmgr_id_data_from_kylo_without_tags() do
    {:ok, body} =
      DiscoveryApi.Test.MockKyloResponse.feedmgr_id_response_without_tags()
      |> Poison.decode()

    body
  end
end
