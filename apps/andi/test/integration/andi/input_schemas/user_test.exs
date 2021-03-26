defmodule Andi.Schemas.UserTest do
  use ExUnit.Case
  use Andi.DataCase

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.Schemas.User
  alias Andi.InputSchemas.Organizations

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

      dataset_id = Ecto.UUID.generate()
      dataset = TDG.create_dataset(%{id: dataset_id}) |> Map.put(:owner_id, id)
      Datasets.update(dataset)

      assert %{id: id, subject_id: user_one_subject_id, datasets: [%{id: dataset_id}]} = User.get_by_subject_id(user_one_subject_id)
    end
  end

  describe "associate_with_organization/2" do
    setup do
      # Create a test user
      subject_id = Ecto.UUID.generate()

      {:ok, user} = User.create_or_update(subject_id, %{email: "foo@bar.com"})

      # Create a test org
      org = Organizations.create()

      %{user: user, subject_id: subject_id, org: org}
    end

    test "associates a user with an organization", %{user: user, subject_id: subject_id, org: org} do
      assert %{subject_id: subject_id} = User.get_by_subject_id(subject_id)

      User.associate_with_organization(subject_id, org.id)

      users = User.get_all()
    end
  end
end
