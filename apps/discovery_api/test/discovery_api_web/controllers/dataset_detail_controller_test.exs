defmodule DiscoveryApiWeb.DatasetDetailControllerTest do
  use ExUnit.Case
  use DiscoveryApiWeb.ConnCase
  use Placebo

describe "fetch dataset detail" do
  test "maps the data to the correct structure", %{conn: conn} do
    mock_feed_detail = generate_feed_detail_entry(7)

    allow HTTPoison.get(any()), return: HttpHelper.create_response(body: mock_feed_detail)

    actual = get(conn, "/v1/api/dataset/1") |> json_response(200)

    expected =
      mock_feed_detail
      |> map_feed_detail

    assert actual == expected
  end

  test "handles HTTPoison errors correctly", %{conn: conn} do
    allow HTTPoison.get(any()), return: HttpHelper.create_response(error_reason: :econnrefused)

    actual = get(conn, "/v1/api/dataset/1") |> json_response(500)

    assert actual == %{"message" => "There was a problem processing your request"}
  end

  test "handles non-200 response codes", %{conn: conn} do
    allow HTTPoison.get(any()), return: HttpHelper.create_response(status_code: 404)

    actual = get(conn, "/v1/api/dataset/1") |> json_response(500)

    assert actual == %{"message" => "There was a problem processing your request"}
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

end

