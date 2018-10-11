defmodule DiscoveryApiWeb.DiscoveryControllerTest do
  use ExUnit.Case
  use DiscoveryApiWeb.ConnCase

  import Mock

  setup do
    Application.put_env(:discovery_api, :data_lake_url, "http://my-fake-cota-url.nope")
  end

  test "maps the data to the correct structure", %{conn: conn} do
    mockFeedMetadata = [generate_entry("Paul"), generate_entry("Richard")]

    with_mocks([
      {HTTPoison, [], [get: fn _url -> {:ok, create_http_response(mockFeedMetadata)} end]}
    ]) do
      actual =
        DiscoveryApiWeb.DiscoveryController.fetch_dataset_summaries(conn, nil)
        |> retrieveResults
        |> Poison.decode!()

      expected = mockFeedMetadata |> Enum.map(&convertToExpected/1)

      assert actual == expected
    end
  end

  test "handles HTTPoison errors correctly", %{conn: conn} do
    with_mocks([
      {HTTPoison, [], [get: fn _url -> {:error, %HTTPoison.Error{id: nil, reason: :econnrefused}} end]}
    ]) do
      actual =
        DiscoveryApiWeb.DiscoveryController.fetch_dataset_summaries(conn, nil)
        |> retrieveResults
        |> Poison.decode!()

      assert actual == %{ "message" => "There was a problem processing your request" }
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

      assert actual == %{ "message" => "There was a problem processing your request" }
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

  defp convertToExpected(metadata) do
    %{
      "description" => metadata["description"],
      "fileTypes" => ["csv"],
      "id" => metadata["id"],
      "systemName" => metadata["systemName"],
      "title" => metadata["displayName"],
    }
  end

  defp create_http_response(body) do
    %HTTPoison.Response{body: Poison.encode!(body)}
  end

  defp retrieveResults(response) do
    %{resp_body: result} = response
    result
  end
end
