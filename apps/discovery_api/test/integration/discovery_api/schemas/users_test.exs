defmodule DiscoveryApi.Schemas.UsersTest do
  use ExUnit.Case
  use Divo, services: [:redis, :"ecto-postgres", :zookeeper, :kafka]
  use DiscoveryApi.DataCase

  alias DiscoveryApi.Repo
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Users.User
  alias DiscoveryApi.Schemas.Organizations.Organization

  describe "get_user/1" do
    test "given an existing user, it returns an :ok tuple with it" do
      {:ok, %{id: saved_id}} = Users.create_or_update("i|exist", %{email: "janet@example.com"})

      assert {:ok, %{id: ^saved_id}} = Users.get_user(saved_id)
    end

    test "can retrieve by the subject id" do
      {:ok, %{id: saved_id, subject_id: saved_subject_id}} = Users.create_or_update("i|exist", %{email: "janet@example.com"})

      assert {:ok, %{id: ^saved_id}} = Users.get_user(saved_subject_id, :subject_id)
    end

    test "given a non-existing user, it returns an :error tuple" do
      hopefully_unique_id = Ecto.UUID.generate()

      assert {:error, _} = Users.get_user(hopefully_unique_id)
    end
  end

  describe "create_or_update/2" do
    test "creates a user" do
      subject_id = "auth0|1"

      assert {:ok, saved} = Users.create_or_update(subject_id, %{email: "Frarf@e.mail"})

      actual = Repo.get(User, saved.id)
      assert %User{subject_id: subject_id, email: "Frarf@e.mail"} = actual
    end

    test "updates a user" do
      subject_id = "auth0|2"

      assert {:ok, created} = Users.create_or_update(subject_id, %{email: "Brarb@e.mail"})
      assert {:ok, updated} = Users.create_or_update(subject_id, %{email: "Crarc@e.mail"})

      actual = Repo.get(User, created.id)
      assert %User{subject_id: subject_id, email: "Crarc@e.mail"} = actual
    end

    test "returns an error when email is not provided for a new user" do
      subject_id = "auth0|3"

      assert {:error, changeset} = Users.create_or_update(subject_id)

      assert changeset.errors |> Keyword.has_key?(:email)
      assert nil == Repo.get_by(User, email: subject_id)
    end
  end

  describe "create/1" do
    test "creates a user" do
      subject_id = "auth0|4"

      assert {:ok, saved} = Users.create(%{subject_id: subject_id, email: "bob@e.mail"})

      actual = Repo.get(User, saved.id)
      assert %User{subject_id: subject_id, email: "bob@e.mail"} = actual
    end

    test "returns an error when subject_id is not unique" do
      subject_id = "auth0|5"
      assert {:ok, _} = Users.create(%{subject_id: subject_id, email: "bob@e.mail"})
      assert {:error, changeset} = Users.create(%{subject_id: subject_id, email: "sally@e.mail"})

      assert changeset.errors |> Keyword.has_key?(:subject_id)
    end
  end

  describe "associate_with_organization/2" do
    setup do
      {:ok, user} = Repo.insert(%User{subject_id: "predicate", email: "bob@e.mail"})
      {:ok, organization} = Repo.insert(%Organization{id: "org-id", name: "my-org", title: "pretty sweet org", ldap_dn: "my-dn"})

      %{user: user, organization: organization}
    end

    test "succeeds when user and organization exist", %{user: user, organization: organization} do
      assert {:ok, saved} = Users.associate_with_organization(user.id, organization.id)

      assert %User{organizations: [organization]} = saved
      assert %User{organizations: [organization]} = Repo.get(User, user.id) |> Repo.preload(:organizations)
    end

    test "fails when user does not exist", %{organization: organization} do
      user_id = Ecto.UUID.generate()
      assert {:error, "User with id #{user_id} does not exist."} == Users.associate_with_organization(user_id, organization.id)
    end

    test "fails when organization does not exist", %{user: user} do
      org_id = "nonexistent-org"
      assert {:error, "Organization with id #{inspect(org_id)} does not exist."} == Users.associate_with_organization(user.id, org_id)
    end

    test "does not add the same organization more than once", %{user: user, organization: organization} do
      assert {:ok, _} = Users.associate_with_organization(user.id, organization.id)
      assert {:ok, _} = Users.associate_with_organization(user.id, organization.id)

      assert {:ok, %User{organizations: [^organization]}} = Users.get_user_with_organizations(user.id)
    end

    test "retains previously saved associated organizations", %{user: user, organization: organization} do
      assert {:ok, _} = Users.associate_with_organization(user.id, organization.id)

      {:ok, other_organization} =
        Repo.insert(%Organization{id: "other-org-id", name: "my-other-org", title: "pretty sweet other org", ldap_dn: "my-other-dn"})

      assert {:ok, _} = Users.associate_with_organization(user.id, other_organization.id)

      {:ok, %User{organizations: organizations}} = Users.get_user_with_organizations(user.id)
      actual = MapSet.new(organizations)
      expected = MapSet.new([organization, other_organization])
      assert expected == actual
    end
  end
end
