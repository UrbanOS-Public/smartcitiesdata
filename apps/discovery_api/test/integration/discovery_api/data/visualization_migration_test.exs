defmodule DiscoveryApi.Data.VisualizationMigratorTest do
  use ExUnit.Case
  use Placebo
  use DiscoveryApi.DataCase
  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Repo
  alias DiscoveryApi.Schemas.Visualizations.Visualization
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Data.VisualizationMigrator
  import SmartCity.TestHelper

  describe "VisualizationMigrator" do
    test "migrates visualizations that need it" do
      allow(RaptorService.list_access_groups_by_dataset(any(), any()), return: %{access_groups: []})
      {:ok, owner} = Users.create_or_update("some|person", %{email: "bob@example.com", name: "Bob"})
      {table, id} = Helper.create_persisted_dataset("123OLD", "old_dataset", "old_org")

      {:ok, saved} =
        %Visualization{}
        |> Visualization.changeset(%{owner: owner, title: "A Viz", query: "select * from #{table}"})
        |> Repo.insert()

      start_supervised!(VisualizationMigrator)

      eventually(fn ->
        actual = Repo.get(Visualization, saved.id)
        assert [id] == actual.datasets
        assert actual.valid_query
      end)
    end
  end
end
