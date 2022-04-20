defmodule RaptorWeb.ListAccessGroupsControllerTest do
  use RaptorWeb.ConnCase
  use Placebo
  alias Raptor.Services.DatasetStore
  alias Raptor.Services.UserOrgAssocStore
  alias Raptor.Services.DatasetAccessGroupRelationStore
  alias Raptor.Services.UserAccessGroupRelationStore

  describe "retrieves access groups by dataset_id" do
    test "returns an empty list when there are no access groups for the given dataset", %{conn: conn} do

      dataset_id = "dataset-without-access-groups"
      expect(DatasetAccessGroupRelationStore.get_all_by_dataset(dataset_id),
        return: []
      )

      actual =
        conn
        |> get("/api/listAccessGroups?dataset_id=#{dataset_id}")
        |> json_response(200)
      expected = %{"access_groups" => []}

      assert actual == expected
    end

    test "returns a list of access groups when there are access groups for the given dataset", %{conn: conn} do

      dataset_id = "dataset-without-access-groups"
      expect(DatasetAccessGroupRelationStore.get_all_by_dataset(dataset_id),
        return: ["access-group1", "access-group2"]
      )

      actual =
        conn
        |> get("/api/listAccessGroups?dataset_id=#{dataset_id}")
        |> json_response(200)
      expected = %{"access_groups" => ["access-group1", "access-group2"]}

      assert actual == expected
    end

  end
end
