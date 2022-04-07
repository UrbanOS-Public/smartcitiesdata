defmodule Andi.Schemas.UserTest do
  use ExUnit.Case
  use Andi.DataCase

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.Schemas.User
  alias Andi.InputSchemas.Organizations
  alias Andi.InputSchemas.AccessGroups
  alias Andi.InputSchemas.AccessGroup
  import SmartCity.TestHelper, only: [eventually: 1]

  @moduletag shared_data_connection: true

  describe "get_all/0" do
    test "returns all users in the system" do
      user_one_id = Ecto.UUID.generate()
      user_one_subject_id = Ecto.UUID.generate()

      user_two_id = Ecto.UUID.generate()
      user_two_subject_id = Ecto.UUID.generate()

      User.create_or_update(user_one_subject_id, %{id: user_one_id, email: "test@test.com", name: "Test"})
      User.create_or_update(user_two_subject_id, %{id: user_two_id, email: "foo@foo.com", name: "Bar"})

      assert [%{subject_id: user_one_subject_id}, %{subject_id: user_two_subject_id}] = User.get_all()
    end
  end

  describe "get_by_subject_id/1" do
    test "returns the user with datasets preloaded" do
      user_one_subject_id = Ecto.UUID.generate()

      {:ok, %{id: id}} = User.create_or_update(user_one_subject_id, %{email: "bar@bar.com", name: "Baz"})

      assert %{subject_id: user_one_subject_id} = User.get_by_subject_id(user_one_subject_id)

      dataset_id = Ecto.UUID.generate()
      dataset = TDG.create_dataset(%{id: dataset_id}) |> Map.put(:owner_id, id)
      Datasets.update(dataset)

      assert %{id: id, subject_id: user_one_subject_id, datasets: [%{id: dataset_id}]} = User.get_by_subject_id(user_one_subject_id)
    end
  end

  describe "associate_with_access_group/2" do
    setup do
      subject_id = Ecto.UUID.generate()
      {:ok, user} = User.create_or_update(subject_id, %{email: "foo@bar.com", name: "Foo Bar"})

      access_group = AccessGroups.create()
      access_group_2 = AccessGroups.create()

      %{user: user, subject_id: subject_id, access_group: access_group, access_group_2: access_group_2}
    end

    test "associates a user with an access group", %{user: user, subject_id: subject_id, access_group: access_group} do
      assert %{subject_id: subject_id} = User.get_by_subject_id(subject_id)

      {:ok, user} = User.associate_with_access_group(subject_id, access_group.id)

      eventually(fn ->
        updated_access_group = Repo.get(AccessGroup, access_group.id) |> Repo.preload(:users)
        assert user.id in Enum.map(updated_access_group.users, fn user -> user.id end)
      end)
    end

    test "a user can be associated with many access_groups", %{
      user: user,
      subject_id: subject_id,
      access_group: access_group,
      access_group_2: access_group_2
    } do
      {:ok, _} = User.associate_with_access_group(subject_id, access_group.id)
      {:ok, _} = User.associate_with_access_group(subject_id, access_group_2.id)

      eventually(fn ->
        updated_access_group = Repo.get(AccessGroup, access_group.id) |> Repo.preload(:users)
        updated_access_group_2 = Repo.get(AccessGroup, access_group_2.id) |> Repo.preload(:users)
        assert user.id in Enum.map(updated_access_group.users, fn user -> user.id end)
        assert user.id in Enum.map(updated_access_group_2.users, fn user -> user.id end)
      end)
    end
  end

  describe "associate_with_organization/2" do
    setup do
      # Create a test user
      subject_id = Ecto.UUID.generate()

      {:ok, user} = User.create_or_update(subject_id, %{email: "foo@bar.com", name: "Foo Bar"})

      # Create test orgs
      org = Organizations.create()
      org_two = Organizations.create()

      %{user: user, subject_id: subject_id, org: org, org_two: org_two}
    end

    test "associates a user with an organization", %{user: user, subject_id: subject_id, org: org} do
      org_id = org.id
      assert %{subject_id: subject_id} = User.get_by_subject_id(subject_id)

      {:ok, user} = User.associate_with_organization(subject_id, org_id)

      eventually(fn ->
        assert [%{id: org_id}] = Map.get(user, :organizations)
      end)
    end

    test "a user can be associated with many organizations", %{user: user, subject_id: subject_id, org: org, org_two: org_two} do
      org_id = org.id
      org_two_id = org_two.id

      {:ok, _} = User.associate_with_organization(subject_id, org_id)
      {:ok, _} = User.associate_with_organization(subject_id, org_two_id)

      eventually(fn ->
        user = User.get_by_subject_id(subject_id)

        assert [%{id: org_id}, %{id: org_two_id}] = Map.get(user, :organizations)
      end)
    end
  end
end
