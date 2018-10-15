defmodule DiscoveryApiWeb.DiscoveryControllerTest do
  use ExUnit.Case
  use DiscoveryApiWeb.ConnCase

  import Mock

  setup do
    Application.put_env(:discovery_api, :data_lake_url, "http://my-fake-cota-url.nope")
  end

  describe "fetch dataset summaries" do
    test "maps the data to the correct structure", %{conn: conn} do
      mockFeedMetadata = [generate_metadata_entry("Paul"), generate_metadata_entry("Richard")]

      with_mocks([
        {HTTPoison, [], [get: fn _url -> {:ok, create_http_response(mockFeedMetadata)} end]}
      ]) do
        actual =
          DiscoveryApiWeb.DiscoveryController.fetch_dataset_summaries(conn, nil)
          |> retrieveResults
          |> Poison.decode!()

        expected = mockFeedMetadata |> Enum.map(&map_metadata/1)

        assert actual == expected
      end
    end

    test "handles HTTPoison errors correctly", %{conn: conn} do
      with_mocks([
        {HTTPoison, [],
         [get: fn _url -> {:error, %HTTPoison.Error{id: nil, reason: :econnrefused}} end]}
      ]) do
        actual =
          DiscoveryApiWeb.DiscoveryController.fetch_dataset_summaries(conn, nil)
          |> retrieveResults
          |> Poison.decode!()

        assert actual == %{"message" => "There was a problem processing your request"}
      end
    end

    test "handles non-200 response codes", %{conn: conn} do
      with_mocks([
        {HTTPoison, [], [get: fn _url -> {:ok, %HTTPoison.Response{status_code: 404}} end]}
      ]) do
        actual =
          DiscoveryApiWeb.DiscoveryController.fetch_dataset_summaries(conn, nil)
          |> retrieveResults
          |> Poison.decode!()

        assert actual == %{"message" => "There was a problem processing your request"}
      end
    end
  end

  describe "fetch dataset detail" do
    test "maps the data to the correct structure", %{conn: conn} do
      mockFeedDetail = generate_feed_detail_entry(7)

      with_mocks([
        {HTTPoison, [], [get: fn _url -> {:ok, create_http_response(mockFeedDetail)} end]}
      ]) do
        actual =
          DiscoveryApiWeb.DiscoveryController.fetch_dataset_detail(conn, nil)
          |> retrieveResults
          |> Poison.decode!()

        expected =
          mockFeedDetail
          |> map_feed_detail

        assert actual == expected
      end
    end

    test "handles HTTPoison errors correctly", %{conn: conn} do
      with_mocks([
        {HTTPoison, [],
         [get: fn _url -> {:error, %HTTPoison.Error{id: nil, reason: :econnrefused}} end]}
      ]) do
        actual =
          DiscoveryApiWeb.DiscoveryController.fetch_dataset_detail(conn, nil)
          |> retrieveResults
          |> Poison.decode!()

        assert actual == %{"message" => "There was a problem processing your request"}
      end
    end

    test "handles non-200 response codes", %{conn: conn} do
      with_mocks([
        {HTTPoison, [], [get: fn _url -> {:ok, %HTTPoison.Response{status_code: 404}} end]}
      ]) do
        actual =
          DiscoveryApiWeb.DiscoveryController.fetch_dataset_detail(conn, nil)
          |> retrieveResults
          |> Poison.decode!()

        assert actual == %{"message" => "There was a problem processing your request"}
      end
    end
  end

  defp generate_feed_detail_entry(id) do
    %{
      "name" => "#{id}-name",
      "description" => "#{id}-description",
      "id" => "#{id}",
      "tags" => ["#{id}-tag1", "#{id}-tag2"],
      "organization" => %{
        "id" => "#{id}-org",
        "name" => "#{id}-org-name",
        "description" => "#{id}-org-desc",
        "image" => "#{id}-org-image"
      }
    }
  end

  defp generate_metadata_entry(id) do
    %{
      "description" => "#{id}-description",
      "displayName" => "#{id}-display-name",
      "systemName" => "#{id}-system-name",
      "id" => "#{id}",
      "blarg" => "#{id}-blarg",
      "unused" => "#{id}-unused"
    }
  end

  defp map_feed_detail(feed_detail) do
    %{
      "name" => feed_detail["feedName"],
      "description" => feed_detail["description"],
      "id" => feed_detail["id"],
      "tags" => feed_detail["tags"],
      "organization" => %{
        "id" => feed_detail["category"]["id"],
        "name" => feed_detail["category"]["displayName"],
        "description" => feed_detail["category"]["description"],
        "image" => "https://www.cota.com/wp-content/uploads/2016/04/COSI-Image-414x236.jpg"
      }
    }
  end

  defp map_metadata(metadata) do
    %{
      "description" => metadata["description"],
      "fileTypes" => ["csv"],
      "id" => metadata["id"],
      "systemName" => metadata["systemName"],
      "title" => metadata["displayName"]
    }
  end

  defp create_http_response(body) do
    %HTTPoison.Response{body: Poison.encode!(body), status_code: 200}
  end

  defp retrieveResults(response) do
    %{resp_body: result} = response
    result
  end
end
