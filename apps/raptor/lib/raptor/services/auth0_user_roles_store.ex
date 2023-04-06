defmodule Raptor.Services.Auth0UserRoleStore do
  @moduledoc """
  This module provides functionality for interacting with Redis
  """
  require Logger
  alias Raptor.Schemas.Auth0UserRole

  @namespace "raptor:auth0_user_roles:"
  @redix Raptor.Application.redis_client()

  @doc """
  Get Auth0 user roles from Redis for a specific user
  """
  @spec get_roles_by_user_id(String.t()) :: list(map())
  def get_roles_by_user_id(user_id) do
    case Redix.command!(@redix, ["KEYS", @namespace <> user_id]) do
      [] ->
        []

      keys ->
        keys
        |> (fn keys -> Redix.command!(@redix, ["MGET" | keys]) end).()
        |> Enum.map(&from_json/1)
        |> Enum.at(0)
    end
  end

  @doc """
  Save a `Raptor.Schemas.Auth0UserRole` to Redis
  """
  @spec persist(String.t(), list(Raptor.Schemas.Auth0UserRole.t())) ::
          Redix.Protocol.redis_value() | no_return()
  def persist(user_id, [%Auth0UserRole{} | _] = auth0_user_roles) do
    json_compatible_list = Enum.map(auth0_user_roles, fn role -> Map.from_struct(role) end)

    json_compatible_list
    |> Jason.encode!()
    |> (fn assoc_json ->
          Redix.command!(@redix, ["SET", @namespace <> user_id, assoc_json, "EX", "3600"])
        end).()
  end

  @doc """
  Remove a `Raptor.Schemas.Auth0UserRole` from Redis
  """
  @spec delete_by_user_id(String.t()) ::
          Redix.Protocol.redis_value() | no_return()
  def delete_by_user_id(user_id) do
    Redix.command!(@redix, ["DEL", @namespace <> user_id])
  end

  defp from_json(json_string) do
    json_string
    |> Jason.decode!(keys: :atoms)
    |> Enum.map(fn role -> struct(%Auth0UserRole{}, role) end)
  end
end
