defmodule DiscoveryApi.Schemas.Users do
  @moduledoc """
  Interface for reading and writing the User schema.
  """
  alias DiscoveryApi.Repo
  alias DiscoveryApi.Schemas.Users.User
  alias DiscoveryApi.Schemas.Organizations

  def list_users do
    Repo.all(User)
  end

  def create(user_attrs) do
    %User{}
    |> User.changeset(user_attrs)
    |> Repo.insert()
  end

  def create_or_update(subject_id, changes \\ %{}) do
    case Repo.get_by(User, subject_id: subject_id) do
      nil -> %User{subject_id: subject_id}
      user -> user
    end
    |> User.changeset(changes)
    |> Repo.insert_or_update()
  end

  def get_user(id, field \\ :id) do
    case Repo.get_by(User, [{field, id}]) do
      nil -> {:error, "User with #{field} #{id} does not exist."}
      user -> {:ok, user}
    end
  rescue
    error in Ecto.Query.CastError -> {:error, "User with #{field} #{id} does not exist: #{inspect(error)}."}
  end

  def get_user_with_organizations(id, field \\ :id) do
    case get_user(id, field) do
      {:ok, user} -> {:ok, user |> Repo.preload(:organizations)}
      error -> error
    end
  end

  def associate_with_organization(user_id, organization_id) do
    with {:ok, user} <- get_user(user_id),
         {:ok, organization} <- Organizations.get_organization(organization_id) do
      user
      |> Repo.preload(:organizations)
      |> User.changeset_add_organization(organization)
      |> Repo.update()
    else
      error -> error
    end
  end
end
