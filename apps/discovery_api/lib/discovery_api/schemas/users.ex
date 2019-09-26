defmodule DiscoveryApi.Schemas.Users do
  @moduledoc """
  Interface for reading and writing the User schema.
  """
  alias DiscoveryApi.Repo
  alias DiscoveryApi.Schemas.Users.User

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

  def get_user(subject_id), do: Repo.get_by(User, subject_id: subject_id)
end
