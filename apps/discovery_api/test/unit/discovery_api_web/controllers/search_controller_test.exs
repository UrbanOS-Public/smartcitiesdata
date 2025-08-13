defmodule DiscoveryApiWeb.SearchControllerTest do
  use DiscoveryApiWeb.ConnCase
  import Mox

  alias DiscoveryApi.Search.Elasticsearch.Search
  alias DiscoveryApi.Schemas.Users.User
  alias DiscoveryApi.Schemas.Organizations.Organization

  setup :verify_on_exit!
  setup :set_mox_from_context

  setup do
    mock_dataset_summaries = [
      generate_model("Paul", ~D(1970-01-01), "remote"),
      generate_model("Richard", ~D(2001-09-09), "ingest")
    ]

    
    # Mock modules that don't have dependency injection
    try do
      :meck.new(Plug.Conn, [:passthrough])
    catch
      :error, {:already_started, _} -> :ok
    end
    :meck.expect(Plug.Conn, :get_req_header, fn _conn, _header -> [] end)
    
    try do
      :meck.new(Search, [:passthrough])
    catch
      :error, {:already_started, _} -> :ok
    end
    
    
    try do
      :meck.new(RaptorService, [:passthrough])
    catch
      :error, {:already_started, _} -> :ok
    end
    :meck.expect(RaptorService, :list_groups_by_api_key, fn _url, _api_key -> 
      %{access_groups: [], organizations: []} 
    end)
    
    stub(ModelMock, :get_all, fn -> mock_dataset_summaries end)
    
    on_exit(fn ->
      try do
        :meck.unload(Plug.Conn)
        :meck.unload(Search)
        :meck.unload(RaptorService)
      catch
        :error, _ -> :ok
      end
    end)
    
    :ok
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
      :meck.expect(Search, :search, fn search_opts ->
        expected_opts = [
          query: "Bob",
          api_accessible: false,
          authorized_organization_ids: [],
          authorized_access_groups: [],
          sort: "name_asc",
          offset: 0,
          limit: 10
        ]
        assert search_opts == expected_opts
        {:ok, mock_dataset_summaries, %{}, 2}
      end)

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

      :meck.expect(Search, :search, fn search_opts ->
        expected_opts = [
          query: "Bob",
          api_accessible: false,
          keywords: ["bobber", "bobbington"],
          authorized_organization_ids: [],
          authorized_access_groups: [],
          sort: "name_asc",
          offset: 0,
          limit: 10
        ]
        assert search_opts == expected_opts
        {:ok, mock_dataset_summaries, mock_facets, 0}
      end)

      params = %{query: "Bob", facets: %{keywords: ["bobber", "bobbington"]}}
      response_map = conn |> get("/api/v2/dataset/search", params) |> json_response(200)
      facets = get_in(response_map, ["metadata", "facets"])

      assert facets == mock_facets
    end

    test "api/v2/search with org title works", %{conn: conn, mock_dataset_summaries: mock_dataset_summaries} do
      mock_facets = %{
        "organization" => [%{"name" => "Bobco", "count" => 2}]
      }

      :meck.expect(Search, :search, fn search_opts ->
        expected_opts = [
          query: "Bob",
          api_accessible: false,
          org_title: "Bobco",
          authorized_organization_ids: [],
          authorized_access_groups: [],
          sort: "name_asc",
          offset: 0,
          limit: 10
        ]
        assert search_opts == expected_opts
        {:ok, mock_dataset_summaries, mock_facets, 0}
      end)

      params = %{query: "Bob", facets: %{organization: ["Bobco"]}}
      response_map = conn |> get("/api/v2/dataset/search", params) |> json_response(200)
      facets = get_in(response_map, ["metadata", "facets"])

      assert facets == mock_facets
    end

    test "api/v2/search with api_accessible works", %{conn: conn, mock_dataset_summaries: mock_dataset_summaries} do
      :meck.expect(Search, :search, fn search_opts ->
        expected_opts = [
          query: "Bob",
          api_accessible: true,
          authorized_organization_ids: [],
          authorized_access_groups: [],
          sort: "name_asc",
          offset: 0,
          limit: 10
        ]
        assert search_opts == expected_opts
        {:ok, mock_dataset_summaries, %{}, 0}
      end)

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
      :meck.expect(RaptorService, :list_groups_by_user, fn _url, _user_id -> %{access_groups: [], organizations: ["1", "2"]} end)

      :meck.expect(Search, :search, fn search_opts ->
        expected_opts = [
          query: "Bob",
          api_accessible: false,
          authorized_organization_ids: ["1", "2"],
          authorized_access_groups: [],
          sort: "name_asc",
          offset: 0,
          limit: 10
        ]
        assert search_opts == expected_opts
        {:ok, mock_dataset_summaries, %{}, 0}
      end)

      params = %{query: "Bob"}
      user = %User{subject_id: "id", organizations: [%Organization{id: "1"}, %Organization{id: "2"}]}

      response_map = conn 
        |> assign(:current_user, user)
        |> get("/api/v2/dataset/search", params) 
        |> json_response(200)

      assert length(mock_dataset_summaries) == length(Map.get(response_map, "results"))
    end

    test "api/v2/search passes logged in user access groups to elasticsearch", %{
      conn: conn,
      mock_dataset_summaries: mock_dataset_summaries
    } do
      :meck.expect(RaptorService, :list_groups_by_user, fn _url, _user_id ->
        %{access_groups: ["access_group_1", "access_group_2"], organizations: []}
      end)

      :meck.expect(Search, :search, fn search_opts ->
        expected_opts = [
          query: "Bob",
          api_accessible: false,
          authorized_organization_ids: [],
          authorized_access_groups: ["access_group_1", "access_group_2"],
          sort: "name_asc",
          offset: 0,
          limit: 10
        ]
        assert search_opts == expected_opts
        {:ok, mock_dataset_summaries, %{}, 0}
      end)

      params = %{query: "Bob"}
      user = %User{subject_id: "id", organizations: []}

      response_map = conn 
        |> assign(:current_user, user)
        |> get("/api/v2/dataset/search", params) 
        |> json_response(200)

      assert length(mock_dataset_summaries) == length(Map.get(response_map, "results"))
    end

    test "api/v2/search passes logged in access group ids to elasticsearch", %{
      conn: conn,
      mock_dataset_summaries: mock_dataset_summaries
    } do
      authorized_access_group_ids = ["321b", "432a"]

      :meck.expect(Search, :search, fn search_opts ->
        expected_opts = [
          query: "Bob",
          api_accessible: false,
          authorized_organization_ids: [],
          authorized_access_groups: authorized_access_group_ids,
          sort: "name_asc",
          offset: 0,
          limit: 10
        ]
        assert search_opts == expected_opts
        {:ok, mock_dataset_summaries, %{}, 0}
      end)

      subject_id = "12345abc"
      user = %User{subject_id: subject_id, organizations: []}
      params = %{query: "Bob"}
      :meck.expect(RaptorService, :list_groups_by_user, fn _url, ^subject_id -> %{access_groups: authorized_access_group_ids, organizations: []} end)

      response_map = conn 
        |> assign(:current_user, user)
        |> get("/api/v2/dataset/search", params) 
        |> json_response(200)
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
