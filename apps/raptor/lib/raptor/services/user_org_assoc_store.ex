defmodule Raptor.Services.UserOrgAssocStore do
  @moduledoc """
  This module provides functionality for interacting with Redis
  """
  require Logger
  alias Raptor.Schemas.UserOrgAssoc
  alias Raptor.Services.RedisKeyScanner

  @namespace "raptor:user_org_assoc:"
  @index_namespace "raptor:user_org_assoc:index:"
  @redix Raptor.Application.redis_client()

  @doc """
  Get all user org associations from Redis
  """
  @spec get_all() :: list(map())
  def get_all() do
    case RedisKeyScanner.scan(@redix, @namespace <> "*") do
      [] ->
        []

      keys ->
        keys
        |> (fn keys -> Redix.command!(@redix, ["MGET" | keys]) end).()
        |> Enum.map(&from_json/1)
    end
  end

  @doc """
  Get all organizations from Redis for a specific user
  """
  @spec get_all_by_user(String.t()) :: list(map())
  def get_all_by_user(user_id) do
    Redix.command!(@redix, ["SMEMBERS", @index_namespace <> user_id])
  end

  @doc """
  Get a given user-org association
  """
  @spec get(String.t(), String.t()) :: map()
  def get(user_id, org_id) do
    key = "#{user_id}:#{org_id}"

    case Redix.command!(@redix, ["GET", @namespace <> key]) do
      nil ->
        Logger.warn("No user org associations exist with user_id #{user_id} and org_id #{org_id}")
        %{}

      assoc_json ->
        from_json(assoc_json)
    end
  end

  @doc """
  Save a `Raptor.Schemas.UserOrgAssoc` to Redis
  """
  @spec persist(Raptor.Schemas.UserOrgAssoc.t()) :: Redix.Protocol.redis_value() | no_return()
  def persist(%UserOrgAssoc{} = user_org_assoc) do
    key = "#{user_org_assoc.user_id}:#{user_org_assoc.org_id}"

    user_org_assoc
    |> Map.from_struct()
    |> Jason.encode!()
    |> (fn assoc_json ->
          Redix.command!(@redix, ["SET", @namespace <> key, assoc_json])
        end).()

    Redix.command!(@redix, [
      "SADD",
      @index_namespace <> user_org_assoc.user_id,
      user_org_assoc.org_id
    ])
  end

  @doc """
  Remove a `Raptor.Schemas.UserOrgAssoc` from Redis
  """
  @spec delete(Raptor.Schemas.UserOrgAssoc.t()) :: Redix.Protocol.redis_value() | no_return()
  def delete(%UserOrgAssoc{} = user_org_assoc) do
    key = "#{user_org_assoc.user_id}:#{user_org_assoc.org_id}"
    Redix.command!(@redix, ["DEL", @namespace <> key])

    Redix.command!(@redix, [
      "SREM",
      @index_namespace <> user_org_assoc.user_id,
      user_org_assoc.org_id
    ])
  end

  defp from_json(json_string) do
    json_string
    |> Jason.decode!(keys: :atoms)
    |> (fn map -> struct(%UserOrgAssoc{}, map) end).()
  end
end
