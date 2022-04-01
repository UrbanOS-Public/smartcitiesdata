defmodule DiscoveryApi.Schemas.VisualizationsTest do
  use ExUnit.Case
  use DiscoveryApi.DataCase
  use DiscoveryApiWeb.Test.AuthConnCase.IntegrationCase

  alias DiscoveryApi.Repo
  alias DiscoveryApi.Schemas.{Generators, Users, Visualizations}
  alias DiscoveryApi.Schemas.Visualizations.Visualization
  alias DiscoveryApi.Schemas.Users.User
  alias DiscoveryApi.Test.Helper

  import SmartCity.TestHelper, only: [eventually: 1]

  @user "me|you"

  describe "get/1" do
    test "given an existing visualization, it returns an :ok tuple with it" do
      {:ok, owner} = Users.create_or_update(@user, %{email: "bob@example.com", name: "Bob"})

      {:ok, %{id: saved_id, public_id: saved_public_id}} =
        Visualizations.create_visualization(%{query: "select * from turtles", owner: owner, title: "My first visualization"})

      assert {:ok, %{id: ^saved_id}} = Visualizations.get_visualization_by_id(saved_public_id)
    end

    test "given a non-existing visualization, it returns an :error tuple" do
      hopefully_unique_id = Generators.generate_public_id(32)

      assert {:error, _} = Visualizations.get_visualization_by_id(hopefully_unique_id)
    end
  end

  describe "get_visualizations_by_owner_id/1" do
    test "gets visualizations for the specified owner" do
      {:ok, owner_1} = Users.create_or_update("mork|mindy", %{email: "dont@matter.com", name: "Dont"})
      {:ok, owner_2} = Users.create_or_update("laverne|shirley", %{email: "dont@matter.com", name: "Dont"})

      {:ok, visualization_1} =
        Visualizations.create_visualization(%{query: "select * from a", owner: owner_1, title: "My first visualization"})

      {:ok, visualization_2} =
        Visualizations.create_visualization(%{query: "select * from b", owner: owner_1, title: "My second visualization"})

      {:ok, _visualization_3} =
        Visualizations.create_visualization(%{query: "select * from c", owner: owner_2, title: "Some other visualization"})

      visualizations = Visualizations.get_visualizations_by_owner_id(owner_1.id)

      assert Enum.any?(visualizations, fn visualization -> visualization.id == visualization_1.id end)
      assert Enum.any?(visualizations, fn visualization -> visualization.id == visualization_2.id end)
    end

    test "returns an empty list when no visualizations are found" do
      assert [] == Visualizations.get_visualizations_by_owner_id(Ecto.UUID.generate())
    end
  end

  describe "create/1" do
    test "given all required attributes, it creates a visualization" do
      query = "select * from turtles"
      title = "My first visualization"
      {:ok, owner} = Users.create_or_update(@user, %{email: "bob@example.com", name: "Bob"})

      assert {:ok, saved} = Visualizations.create_visualization(%{query: query, owner: owner, title: title})

      actual = Repo.get(Visualization, saved.id)
      assert query == actual.query
    end

    test "given a valid query, it is created with a list of datasets used in it and is flagged valid" do
      {table, id} = Helper.create_persisted_dataset("123A", "public_dataset_a", "public_org")
      query = "select * from #{table}"
      title = "My first visualization"
      {:ok, owner} = Users.create_or_update(@user, %{email: "bob@example.com", name: "Bob"})

      assert {:ok, saved} = Visualizations.create_visualization(%{query: query, owner: owner, title: title})

      actual = Repo.get(Visualization, saved.id)
      assert [id] == actual.datasets
      assert actual.valid_query
    end

    test "given a valid query using the same dataset twice, the saved list of datasets contains only one entry for it" do
      {table, id} = Helper.create_persisted_dataset("123AB", "public_dataset_b", "public_org")
      query = "select * from #{table} union all select * from #{table}"
      title = "My first visualization"
      {:ok, owner} = Users.create_or_update(@user, %{email: "bob@example.com", name: "Bob"})

      assert {:ok, saved} = Visualizations.create_visualization(%{query: query, owner: owner, title: title})

      actual = Repo.get(Visualization, saved.id)
      assert [id] == actual.datasets
      assert actual.valid_query
    end

    test "given an invalid query, it is created with an empty list of datasets and is flagged invalid" do
      {table, _id} = Helper.create_persisted_dataset("123AC", "public_dataset_c", "public_org")
      query = "select * from INVALID #{table}"
      title = "My first visualization"
      {:ok, owner} = Users.create_or_update(@user, %{email: "bob@example.com", name: "Bob"})

      assert {:ok, saved} = Visualizations.create_visualization(%{query: query, owner: owner, title: title})

      actual = Repo.get(Visualization, saved.id)
      assert [] == actual.datasets
      refute actual.valid_query
    end

    test "given a query containing a dataset the user is not authorized to query, it is created with an empty list of datasets and is flagged invalid" do
      {table, _id} = Helper.create_persisted_dataset("123AD", "private_dataset_d", "private_org", true)
      query = "select * from #{table}"
      title = "My first visualization"
      {:ok, owner} = Users.create_or_update(@user, %{email: "bob@example.com", name: "Bob"})
      {:ok, owner_with_orgs} = Users.get_user_with_organizations(owner.id)

      assert {:ok, saved} = Visualizations.create_visualization(%{query: query, owner: owner_with_orgs, title: title})

      actual = Repo.get(Visualization, saved.id)
      assert [] == actual.datasets
      refute actual.valid_query
    end

    test "given a missing query, it fails to create a visualization" do
      title = "My first visualization"
      {:ok, owner} = Users.create_or_update(@user, %{email: "bob@example.com", name: "Bob"})

      assert {:error, _} = Visualizations.create_visualization(%{owner: owner, title: title})
    end

    test "given a missing title, it fails to create a visualization" do
      query = "select * from turtles"
      {:ok, owner} = Users.create_or_update(@user, %{email: "bob@example.com", name: "Bob"})

      assert {:error, _} = Visualizations.create_visualization(%{query: query, owner: owner})
    end

    test "given a missing owner, it fails to create a visualization" do
      query = "select * from turtles"
      title = "My first visualization"

      assert {:error, _} = Visualizations.create_visualization(%{query: query, title: title})
    end

    test "given an invalid owner, it fails to create a visualization" do
      query = "select * from turtles"
      title = "My first visualization"
      owner = %User{id: Ecto.UUID.generate(), subject_id: "you|them"}

      assert_raise Postgrex.Error, fn ->
        Visualizations.create_visualization(%{query: query, title: title, owner: owner})
      end
    end

    test "given a chart larger than twenty thousand bytes, it fails to create a visualization" do
      query = "blah"
      title = "blah blah"
      chart = Faker.String.base64(20_001)
      {:ok, owner} = Users.create_or_update(@user, %{email: "bob@example.com", name: "Bob"})

      assert {:error, _} = Visualizations.create_visualization(%{query: query, title: title, owner: owner, chart: chart})
    end

    test "given a query larger than twenty thousand bytes, it fails to create a visualization" do
      query = Faker.String.base64(20_001)
      title = "blah blah"
      {:ok, owner} = Users.create_or_update(@user, %{email: "bob@example.com", name: "Bob"})

      assert {:error, _} = Visualizations.create_visualization(%{query: query, title: title, owner: owner})
    end

    test "given a query and chart smaller than twenty thousand bytes, it creates a visualization" do
      query = Faker.String.base64(19_999)
      title = "blah blah"
      chart = Faker.String.base64(19_999)
      {:ok, owner} = Users.create_or_update(@user, %{email: "bob@example.com", name: "Bob"})

      assert {:ok, saved} = Visualizations.create_visualization(%{query: query, title: title, owner: owner, chart: chart})
    end

    test "given a non-existent owner, it creates the visualization and the owner" do
      query = "select * from turtles"
      title = "My first visualization"
      owner = %User{subject_id: "you|them", email: "bob@example.com", name: "Bob"}

      assert {:ok, _} = Visualizations.create_visualization(%{query: query, title: title, owner: owner})
      assert {:ok, _} = Users.get_user("you|them", :subject_id)
    end
  end

  describe "update/2" do
    setup %{authorized_subject: subject} do
      {:ok, owner} = Users.create_or_update(subject, %{email: "bob@example.com", name: "Bob"})

      visualization = %{title: "query title", query: "select * FROM table", owner: owner}
      {:ok, created_visualization} = Visualizations.create_visualization(visualization)

      %{created_visualization: created_visualization, owner: owner}
    end

    test "updates saved visualization given a valid id and owner",
         %{
           created_visualization: created_visualization,
           owner: owner
         } do
      assert {:ok, updated_visualization} =
               Visualizations.update_visualization_by_id(
                 created_visualization.public_id,
                 %{
                   title: "query title updated",
                   query: "select * FROM table2"
                 },
                 owner
               )

      {:ok, actual_visualization} = Visualizations.get_visualization_by_id(created_visualization.public_id)

      assert updated_visualization.title == actual_visualization.title
      assert updated_visualization.query == actual_visualization.query
    end

    test "does not update when the owner has changed", %{created_visualization: created_visualization} do
      new_user = Users.create_or_update("differentUser", %{email: "cam@example.com", name: "Bob"})

      assert {:error, "User does not have permission to update this visualization."} ==
               Visualizations.update_visualization_by_id(
                 created_visualization.public_id,
                 %{
                   title: "query title updated",
                   query: "select * FROM table2"
                 },
                 elem(new_user, 1)
               )
    end

    test "does not allow chart length to increase more than the character limit",
         %{created_visualization: created_visualization, owner: owner} do
      new_chart = Faker.String.base64(20_001)

      assert {:error, _} =
               Visualizations.update_visualization_by_id(
                 created_visualization.public_id,
                 %{chart: new_chart},
                 owner
               )
    end

    test "given a valid query through the API, it is updated with a list of datasets used in it", %{
      created_visualization: created_visualization,
      owner: _owner,
      authorized_conn: authorized_conn
    } do
      {table, id} = Helper.create_persisted_dataset("123A", "a_table", "a_org")

      put_body = ~s({"query": "select * from #{table}", "title": "My favorite title", "chart": {"data": "hello"}})

      assert put(authorized_conn, "/api/v1/visualization/#{created_visualization.public_id}", put_body)
             |> response(200)

      eventually(fn ->
        {:ok, viz} = Visualizations.get_visualization_by_id(created_visualization.public_id)
        assert [id] == viz.datasets
      end)
    end
  end
end
