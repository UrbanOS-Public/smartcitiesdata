defmodule DiscoveryApiWeb.DiscoveryControllerTest do
  use ExUnit.Case
  use DiscoveryApiWeb.ConnCase

  import Mock

  setup do
    Application.put_env(:discovery_api, :data_lake_url, "http://my-fake-cota-url.nope")
  end

  test "GET /api/fetchDatasetSummaries", %{conn: conn} do
    with_mocks([
      {HTTPoison, [], [get: fn _url -> {:ok, create_http_response([])} end]}
    ]) do
      DiscoveryApiWeb.DiscoveryController.fetch_dataset_summaries(conn, nil)

      assert called(HTTPoison.get("http://my-fake-cota-url.nope/v1/metadata/feed"))
    end
  end

  test "returns the description for each feed", %{conn: conn} do
    mockFeedMetadata = [generate_entry("Paul"), generate_entry("Richard")]

    with_mocks([
      {HTTPoison, [], [get: fn _url -> {:ok, create_http_response(mockFeedMetadata)} end]}
    ]) do
      actual =
        DiscoveryApiWeb.DiscoveryController.fetch_dataset_summaries(conn, nil)
        |> retrieveResults
        |> Poison.decode!()

      assert length(actual) == length(mockFeedMetadata)
      actual |> Enum.each(fn input -> assert map_size(input) == 5 end)

      assert get_properties(actual, "description") ==
               get_properties(mockFeedMetadata, "description")

      assert get_properties(actual, "title") ==
               get_properties(mockFeedMetadata, "displayName")

      assert get_properties(actual, "systemName") ==
               get_properties(mockFeedMetadata, "systemName")

      assert get_properties(actual, "id") == get_properties(mockFeedMetadata, "id")
      assert get_properties(actual, "fileTypes") == Enum.map(mockFeedMetadata, fn _ -> ["csv"] end)
    end
  end

  defp generate_entry(id) do
    %{
      "description" => "#{id}-description",
      "displayName" => "#{id}-display-name",
      "systemName" => "#{id}-system-name",
      "id" => "#{id}",
      "blarg" => "#{id}-blarg",
      "unused" => "#{id}-unused"
    }
  end

  defp create_http_response(body) do
    %HTTPoison.Response{body: Poison.encode!(body)}
  end

  defp retrieveResults(response) do
    %{resp_body: result} = response
    result
  end

  defp get_properties(stuff, property) do
    stuff |> Enum.map(fn input -> input[property] end)
  end
end
