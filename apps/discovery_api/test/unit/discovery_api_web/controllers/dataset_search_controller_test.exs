defmodule DiscoveryApiWeb.DatasetSearchControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  setup do
    mock_dataset_summaries = [
      generate_dataset("Paul", ~D(1970-01-01)),
      generate_dataset("Richard", ~D(2001-09-09))
    ]

    allow DiscoveryApi.Data.Retriever.get_datasets(), return: mock_dataset_summaries
    :ok
  end

  describe "fetch dataset summaries" do
    test "returns metadata", %{conn: conn} do
      actual = get(conn, "/v1/api/dataset/search", sort: "name_asc") |> json_response(200)

      assert actual["metadata"]["totalDatasets"] == 2
    end

    test "returns given limit in metadata", %{conn: conn} do
      actual = get(conn, "/v1/api/dataset/search", sort: "name_asc", limit: "5") |> json_response(200)

      assert actual["metadata"]["limit"] == 5
    end

    test "uses default of 10 for limit", %{conn: conn} do
      actual = get(conn, "/v1/api/dataset/search", sort: "name_asc") |> json_response(200)

      assert actual["metadata"]["limit"] == 10
    end

    test "returns given offset in metadata", %{conn: conn} do
      actual = get(conn, "/v1/api/dataset/search", sort: "name_asc", offset: "5") |> json_response(200)

      assert actual["metadata"]["offset"] == 5
    end

    test "uses default of 0 for offset", %{conn: conn} do
      actual = get(conn, "/v1/api/dataset/search", sort: "name_asc") |> json_response(200)

      assert actual["metadata"]["offset"] == 0
    end

    test "returns organization facets", %{conn: conn} do
      actual = get(conn, "/v1/api/dataset/search", sort: "name_asc") |> json_response(200)

      assert Enum.at(actual["metadata"]["facets"]["organization"], 0)["name"] == "Paul Co."
      assert Enum.at(actual["metadata"]["facets"]["organization"], 0)["count"] == 1

      assert Enum.at(actual["metadata"]["facets"]["organization"], 1)["name"] == "Richard Co."
      assert Enum.at(actual["metadata"]["facets"]["organization"], 1)["count"] == 1
    end

    test "returns keywords facets", %{conn: conn} do
      actual = get(conn, "/v1/api/dataset/search", sort: "name_asc") |> json_response(200)

      assert Enum.at(actual["metadata"]["facets"]["keywords"], 0)["name"] == "Paul keywords"
      assert Enum.at(actual["metadata"]["facets"]["keywords"], 0)["count"] == 1

      assert Enum.at(actual["metadata"]["facets"]["keywords"], 1)["name"] == "Richard keywords"
      assert Enum.at(actual["metadata"]["facets"]["keywords"], 1)["count"] == 1
    end

    test "sort by name ascending", %{conn: conn} do
      actual = get(conn, "/v1/api/dataset/search", sort: "name_asc") |> json_response(200)

      assert Enum.at(actual["results"], 0)["id"] == "Paul"
      assert Enum.at(actual["results"], 1)["id"] == "Richard"
    end

    test "sort by name descending", %{conn: conn} do
      actual = get(conn, "/v1/api/dataset/search", sort: "name_desc") |> json_response(200)

      assert Enum.at(actual["results"], 0)["id"] == "Richard"
      assert Enum.at(actual["results"], 1)["id"] == "Paul"
    end

    test "sort by date descending", %{conn: conn} do
      actual = get(conn, "/v1/api/dataset/search", sort: "last_mod") |> json_response(200)

      assert Enum.at(actual["results"], 0)["id"] == "Richard"
      assert Enum.at(actual["results"], 1)["id"] == "Paul"
    end

    test "paginate datasets", %{conn: conn} do
      actual =
        get(conn, "/v1/api/dataset/search", sort: "name_asc", limit: "1", offset: "0")
        |> json_response(200)

      assert Enum.at(actual["results"], 0)["id"] == "Paul"
      assert Enum.count(actual["results"]) == 1
    end

    test "paginate datasets offset", %{conn: conn} do
      actual =
        get(conn, "/v1/api/dataset/search", sort: "name_asc", limit: "1", offset: "1")
        |> json_response(200)

      assert Enum.at(actual["results"], 0)["id"] == "Richard"
      assert Enum.count(actual["results"]) == 1
    end

    test "paginate datasets offset default", %{conn: conn} do
      actual = get(conn, "/v1/api/dataset/search", sort: "name_asc", limit: "1") |> json_response(200)

      assert Enum.at(actual["results"], 0)["id"] == "Paul"
      assert Enum.count(actual["results"]) == 1
    end

    test "facets in query string are used to filter the datasets", %{conn: conn} do
      actual =
        get(conn, "/v1/api/dataset/search", facets: %{organization: ["Richard Co."]})
        |> json_response(200)

      assert Enum.at(actual["results"], 0)["id"] == "Richard"
      assert Enum.count(actual["results"]) == 1
    end
  end

  test "Non integer offset should throw error", %{conn: conn} do
    actual =
      conn
      |> get("/v1/api/dataset/search", offset: "not a number")
      |> json_response(400)

    assert Map.has_key?(actual, "message")
  end

  test "Non integer limit should throw error", %{conn: conn} do
    actual =
      conn
      |> get("/v1/api/dataset/search", limit: "not a number")
      |> json_response(400)

    assert Map.has_key?(actual, "message")
  end

  test "Non existing facets should throw error", %{conn: conn} do
    actual =
      conn
      |> get("/v1/api/dataset/search", facets: %{"not a facet" => ["ignored value"]})
      |> json_response(400)

    assert Map.has_key?(actual, "message")
  end

  defp generate_dataset(id, date) do
    %DiscoveryApi.Data.Dataset{
      description: "#{id}-description",
      fileTypes: ["csv"],
      id: id,
      title: "#{id}-title",
      modified: "#{date}",
      organization: "#{id} Co.",
      keywords: ["#{id} keywords"]
    }
  end
end
