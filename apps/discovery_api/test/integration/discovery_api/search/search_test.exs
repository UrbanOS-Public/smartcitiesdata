defmodule DiscoveryApi.Data.Search.SearchTest do
  use DiscoveryApiWeb.ConnCase
  use Divo, services: [:redis, :"ecto-postgres", :zookeeper, :kafka, :elasticsearch]
  use DiscoveryApi.ElasticSearchCase
  use DiscoveryApi.DataCase
  import SmartCity.TestHelper, only: [eventually: 3]

  alias DiscoveryApi.Test.Helper
  alias SmartCity.TestDataGenerator, as: TDG

  @organization_id_1 "11119ccf-de9f-4229-842f-e3733972d111"
  # @organization_id_2 "2225a13d-cad6-48fb-b46f-97f321e16222"
  # @organization_id_3 "333f5b9d-3771-4ba0-a28e-9e1e85ca7333"

  setup_all do
    Helper.wait_for_brook_to_be_ready()
    :ok
  end

  describe "sort" do
    test "should default by title ascending", %{conn: conn} do
      create_dataset(%{id: "1", business: %{dataTitle: "Zoo"}})
      create_dataset(%{id: "2", business: %{dataTitle: "Alphabet"}})
      create_dataset(%{id: "3", business: %{dataTitle: "2020 Zones"}})
      params = %{}

      local_eventually(fn ->
        response_map = conn |> get("/api/v2/dataset/search", params) |> json_response(200)

        assert ["2020 Zones", "Alphabet", "Zoo"] ==
                 response_map |> Map.get("results") |> Enum.map(fn model -> Map.get(model, "title") end)
      end)
    end

    test "should allow by title descending", %{conn: conn} do
      create_dataset(%{id: "1", business: %{dataTitle: "Zoo"}})
      create_dataset(%{id: "2", business: %{dataTitle: "Alphabet"}})
      create_dataset(%{id: "3", business: %{dataTitle: "2020 Zones"}})
      params = %{sort: "name_desc"}

      local_eventually(fn ->
        response_map = conn |> get("/api/v2/dataset/search", params) |> json_response(200)

        assert ["Zoo", "Alphabet", "2020 Zones"] ==
                 response_map |> Map.get("results") |> Enum.map(fn model -> Map.get(model, "title") end)
      end)
    end

    test "sort should allow for last_mod", %{conn: conn} do
      create_dataset(%{id: "1", business: %{modifiedDate: "2020-03-11T00:00:00Z"}})
      create_dataset(%{id: "2", business: %{modifiedDate: "2020-06-01T00:00:00Z"}})
      create_dataset(%{id: "3", business: %{modifiedDate: "2000-01-01T00:00:00Z"}})
      params = %{sort: "last_mod"}

      local_eventually(fn ->
        response_map = conn |> get("/api/v2/dataset/search", params) |> json_response(200)

        assert ["2", "1", "3"] == response_map |> Map.get("results") |> Enum.map(fn model -> Map.get(model, "id") end)
      end)
    end

    test "sort should allow for relevance", %{conn: conn} do
      create_dataset(%{id: "0", business: %{dataTitle: "Unrelated to the others"}})
      create_dataset(%{id: "1", business: %{dataTitle: "Traffic Signals"}})
      create_dataset(%{id: "2", business: %{dataTitle: "Traffic"}})
      create_dataset(%{id: "3", business: %{dataTitle: "Traffic Signal Locations"}})
      params = %{sort: "relevance", query: "traffic"}

      local_eventually(fn ->
        response_map = conn |> get("/api/v2/dataset/search", params) |> json_response(200)

        assert ["2", "1", "3"] == response_map |> Map.get("results") |> Enum.map(fn model -> Map.get(model, "id") end)
      end)
    end
  end

  defp create_dataset(overrides) do
    create_organization(@organization_id_1)

    dataset =
      overrides
      |> Map.merge(%{technical: %{orgId: @organization_id_1}})
      |> TDG.create_dataset()

    Brook.Event.send(DiscoveryApi.instance(), "dataset:update", :integration_test, dataset)
    dataset
  end

  defp create_organization(id) do
    organization = TDG.create_organization(%{id: id})
    Brook.Event.send(DiscoveryApi.instance(), "organization:update", :integration_test, organization)
  end

  defp local_eventually(function) do
    eventually(function, 250, 10)
  end
end
