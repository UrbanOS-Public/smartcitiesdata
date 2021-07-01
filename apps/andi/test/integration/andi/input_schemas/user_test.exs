defmodule Andi.Schemas.UserTest do
  use ExUnit.Case
  use Andi.DataCase

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.Schemas.User
  alias Andi.InputSchemas.Organizations
  import SmartCity.TestHelper, only: [eventually: 1]

  @moduletag shared_data_connection: true

  describe "get_all/0" do
    test "returns all users in the system" do
      user_one_id = Ecto.UUID.generate()
      user_one_subject_id = Ecto.UUID.generate()

      user_two_id = Ecto.UUID.generate()
      user_two_subject_id = Ecto.UUID.generate()

      User.create_or_update(user_one_subject_id, %{id: user_one_id, email: "test@test.com"})
      User.create_or_update(user_two_subject_id, %{id: user_two_id, email: "foo@foo.com"})

      assert [%{subject_id: user_one_subject_id}, %{subject_id: user_two_subject_id}] = User.get_all()
    end
  end

  describe "get_by_subject_id/1" do
    test "returns the user with datasets preloaded" do
      user_one_subject_id = Ecto.UUID.generate()

      {:ok, %{id: id}} = User.create_or_update(user_one_subject_id, %{email: "bar@bar.com"})

      assert %{subject_id: user_one_subject_id} = User.get_by_subject_id(user_one_subject_id)

      smrt_org = TDG.create_organization(%{})
      Organizations.update(smrt_org)
      dataset_id = Ecto.UUID.generate()
      dataset = TDG.create_dataset(%{id: dataset_id, organization_id: smrt_org.id}) |> Map.put(:owner_id, id)
      Datasets.update(dataset)

      assert %{id: id, subject_id: user_one_subject_id, datasets: [%{id: dataset_id}]} = User.get_by_subject_id(user_one_subject_id)
    end
  end

  describe "associate_with_organization/2" do
    setup do
      # Create a test user
      subject_id = Ecto.UUID.generate()

      {:ok, user} = User.create_or_update(subject_id, %{email: "foo@bar.com"})

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
