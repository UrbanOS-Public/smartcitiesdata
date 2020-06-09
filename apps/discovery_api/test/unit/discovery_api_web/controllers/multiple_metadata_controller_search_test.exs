defmodule DiscoveryApiWeb.MultipleMetadataController.SearchTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  import Checkov
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Search.Elasticsearch.Search
  alias DiscoveryApi.Schemas.Users.User
  alias DiscoveryApi.Schemas.Organizations.Organization

  setup do
    mock_dataset_summaries = [
      generate_model("Paul", ~D(1970-01-01), "remote"),
      generate_model("Richard", ~D(2001-09-09), "ingest")
    ]

    allow(Model.get_all(), return: mock_dataset_summaries)
    :ok
  end

  describe "fetch dataset summaries" do
    data_test "request to search with #{inspect(params)}", %{conn: conn} do
      response_map = conn |> get("/api/v1/dataset/search", params) |> json_response(200)
      actual = get_in(response_map, selector)

      assert actual == result

      where([
        [:params, :selector, :result],
        [[sort: "name_asc"], ["metadata", "totalDatasets"], 2],
        [[sort: "name_asc", limit: "5"], ["metadata", "limit"], 5],
        [[sort: "name_asc", limit: "1"], ["metadata", "totalDatasets"], 2],
        [[sort: "name_asc"], ["metadata", "limit"], 10],
        [[sort: "name_asc", offset: "5"], ["metadata", "offset"], 5],
        [[sort: "name_asc"], ["metadata", "offset"], 0],
        [
          [sort: "name_asc"],
          ["metadata", "facets", "organization", Access.all(), "name"],
          ["Paul Co.", "Richard Co."]
        ],
        [
          [sort: "name_asc"],
          ["metadata", "facets", "organization", Access.all(), "count"],
          [1, 1]
        ],
        [
          [sort: "name_asc"],
          ["metadata", "facets", "keywords", Access.all(), "name"],
          ["Paul keywords", "Richard keywords"]
        ],
        [
          [sort: "name_asc"],
          ["metadata", "facets", "keywords", Access.all(), "count"],
          [1, 1]
        ],
        [
          [sort: "name_asc"],
          ["results", Access.all(), "id"],
          ["Paul", "Richard"]
        ],
        [
          [sort: "name_desc"],
          ["results", Access.all(), "id"],
          ["Richard", "Paul"]
        ],
        [
          [sort: "last_mod"],
          ["results", Access.all(), "id"],
          ["Richard", "Paul"]
        ],
        [
          [sort: "name_asc", limit: "1", offset: "0"],
          ["results", Access.all(), "id"],
          ["Paul"]
        ],
        [
          [sort: "name_asc", limit: "1", offset: "1"],
          ["results", Access.all(), "id"],
          ["Richard"]
        ],
        [
          [sort: "name_asc", limit: "1"],
          ["results", Access.all(), "id"],
          ["Paul"]
        ],
        [
          [facets: %{organization: ["Richard Co."]}],
          ["results", Access.all(), "id"],
          ["Richard"]
        ],
        [
          [facets: %{organization: ["Babs"], keywords: ["Fruit"]}],
          ["metadata", "facets"],
          %{
            "keywords" => [%{"name" => "Fruit", "count" => 0}],
            "organization" => [%{"name" => "Babs", "count" => 0}]
          }
        ],
        [
          [apiAccessible: "TrUe"],
          ["results", Access.all(), "id"],
          ["Richard"]
        ],
        [
          [apiAccessible: "FaLse"],
          ["results", Access.all(), "id"],
          ["Paul", "Richard"]
        ],
        [
          [apiAccessible: "SomethingINVALID"],
          ["results", Access.all(), "id"],
          ["Paul", "Richard"]
        ]
      ])
    end
  end

  describe "fetch dataset summaries - error cases" do
    data_test "request to search #{inspect(params)} returns a 400 with an error message",
              %{conn: conn} do
      actual = conn |> get("/api/v1/dataset/search", params) |> json_response(400)
      assert Map.has_key?(actual, "message")

      where([
        [:params],
        [[offset: "not a number"]],
        [[limit: "not a number"]],
        [[facets: %{"not a facet" => ["ignored value"]}]]
      ])
    end
  end

  describe "advanced search" do
    setup do
      mock_dataset_summaries = [
        generate_model("DataOne", ~D(1970-01-01), "remote"),
        generate_model("DataTwo", ~D(2001-09-09), "ingest")
      ]

      {:ok, mock_dataset_summaries: mock_dataset_summaries}
    end

    test "api/v2/search works", %{conn: conn, mock_dataset_summaries: mock_dataset_summaries} do
      expect(Search.search(query: "Bob", api_accessible: false, sort: "name_asc", offset: 0, limit: 10), return: {:ok, mock_dataset_summaries, %{}, 2})

      params = %{query: "Bob"}
      response_map = conn |> get("/api/v2/dataset/search", params) |> json_response(200)
      total_datasets = get_in(response_map, ["metadata", "totalDatasets"])
      dataset_ids = get_in(response_map, ["results", Access.all(), "id"])

      assert total_datasets == 2
      assert dataset_ids == ["DataOne", "DataTwo"]
    end

    test "api/v2/search with keywords works", %{conn: conn, mock_dataset_summaries: mock_dataset_summaries} do
      mock_facets = %{
        "keywords" => [%{"name" => "bobber", "count" => 1}, %{"name" => "bobbington", "count" => 1}]
      }

      expect(Search.search(query: "Bob", api_accessible: false, keywords: ["bobber", "bobbington"], sort: "name_asc", offset: 0, limit: 10),
        return: {:ok, mock_dataset_summaries, mock_facets, 0}
      )

      params = %{query: "Bob", facets: %{keywords: ["bobber", "bobbington"]}}
      response_map = conn |> get("/api/v2/dataset/search", params) |> json_response(200)
      facets = get_in(response_map, ["metadata", "facets"])

      assert facets == mock_facets
    end

    test "api/v2/search with org title works", %{conn: conn, mock_dataset_summaries: mock_dataset_summaries} do
      mock_facets = %{
        "organization" => [%{"name" => "Bobco", "count" => 2}]
      }

      expect(Search.search(query: "Bob", api_accessible: false, org_title: "Bobco", sort: "name_asc", offset: 0, limit: 10),
        return: {:ok, mock_dataset_summaries, mock_facets, 0}
      )

      params = %{query: "Bob", facets: %{organization: ["Bobco"]}}
      response_map = conn |> get("/api/v2/dataset/search", params) |> json_response(200)
      facets = get_in(response_map, ["metadata", "facets"])

      assert facets == mock_facets
    end

    test "api/v2/search with api_accessible works", %{conn: conn, mock_dataset_summaries: mock_dataset_summaries} do
      expect(Search.search(query: "Bob", api_accessible: true, sort: "name_asc", offset: 0, limit: 10), return: {:ok, mock_dataset_summaries, %{}, 0})

      params = %{query: "Bob", apiAccessible: "true"}
      conn |> get("/api/v2/dataset/search", params) |> json_response(200)
    end

    test "api/v2/search with bad facets returns 400", %{conn: conn} do
      params = %{query: "Bob", facets: %{"not a facet" => ["ignored value"]}}
      conn |> get("/api/v2/dataset/search", params) |> json_response(400)
    end

    test "api/v2/search passes logged in user organization ids to elasticsearch", %{
      conn: conn,
      mock_dataset_summaries: mock_dataset_summaries
    } do
      expect(Search.search(query: "Bob", api_accessible: false, authorized_organization_ids: ["1", "2"], sort: "name_asc", offset: 0, limit: 10),
        return: {:ok, mock_dataset_summaries, %{}, 0}
      )

      params = %{query: "Bob"}
      user = %User{organizations: [%Organization{id: "1"}, %Organization{id: "2"}]}
      allow(Guardian.Plug.current_resource(any()), return: user, meck_options: [:passthrough])

      response_map = conn |> get("/api/v2/dataset/search", params) |> json_response(200)

      assert length(mock_dataset_summaries) == length(Map.get(response_map, "results"))
    end
  end

  defp generate_model(id, date, sourceType) do
    Helper.sample_model(%{
      description: "#{id}-description",
      fileTypes: ["csv"],
      id: id,
      name: "#{id}-name",
      title: "#{id}-title",
      modifiedDate: "#{date}",
      organization: "#{id} Co.",
      keywords: ["#{id} keywords"],
      sourceType: sourceType,
      organizationDetails: %{
        orgTitle: "#{id}-org-title",
        orgName: "#{id}-org-name",
        logoUrl: "#{id}-org.png"
      },
      private: false
    })
  end
end
