defmodule Raptor.Services.UserAccessGroupRelationStore do
  @moduledoc """
  This module provides functionality for interacting with Redis
  """
  require Logger
  alias Raptor.Schemas.UserAccessGroupRelation

  @namespace "raptor:user_access_group_relation:"
  @redix Raptor.Application.redis_client()

  @doc """
  Get all user access group relations from Redis
  """
  @spec get_all() :: list(map())
  def get_all() do
    case Redix.command!(@redix, ["KEYS", @namespace <> "*"]) do
      [] ->
        []

      keys ->
        keys
        |> (fn keys -> Redix.command!(@redix, ["MGET" | keys]) end).()
        |> Enum.map(&from_json/1)
    end
  end

  @doc """
  Get all access groups from Redis for a specific user
  """
  @spec get_all_by_user(String.t()) :: list(map())
  def get_all_by_user(user_id) do
    case Redix.command!(@redix, ["KEYS", @namespace <> user_id <> ":*"]) do
      [] ->
        []

      keys ->
        keys
        |> (fn keys -> Redix.command!(@redix, ["MGET" | keys]) end).()
        |> Enum.map(&from_json/1)
        |> Enum.map(fn relation -> relation.access_group_id end)
    end
  end

  @doc """
  Get a given user-access_group relation
  """
  @spec get(String.t(), String.t()) :: map()
  def get(user_id, access_group_id) do
    key = "#{user_id}:#{access_group_id}"
    matching_entries = Redix.command!(@redix, ["KEYS", @namespace <> key])

    case length(matching_entries) do
      0 ->
        Logger.warn(
          "No user access group relations exist with user_id #{user_id} and access_group_id #{access_group_id}"
        )

        %{}

      1 ->
        assoc_key = matching_entries |> List.first()
        Redix.command!(@redix, ["MGET", assoc_key]) |> Enum.map(&from_json/1) |> List.first()

      _ ->
        Logger.warn(
          "Multiple user-access_group relations match #{user_id}:#{access_group_id}. Cannot continue."
        )

        %{}
    end
  end

  @doc """
  Save a `Raptor.Schemas.UserAccessGroupRelation` to Redis
  """
  @spec persist(Raptor.Schemas.UserAccessGroupRelation.t()) ::
          Redix.Protocol.redis_value() | no_return()
  def persist(%UserAccessGroupRelation{} = user_access_group_relation) do
    key = "#{user_access_group_relation.user_id}:#{user_access_group_relation.access_group_id}"

    user_access_group_relation
    |> Map.from_struct()
    |> Jason.encode!()
    |> (fn assoc_json ->
          Redix.command!(@redix, ["SET", @namespace <> key, assoc_json])
        end).()
  end

  @doc """
  Remove a `Raptor.Schemas.UserAccessGroupRelation` from Redis
  """
  @spec delete(Raptor.Schemas.UserAccessGroupRelation.t()) ::
          Redix.Protocol.redis_value() | no_return()
  def delete(%UserAccessGroupRelation{} = user_access_group_relation) do
    key = "#{user_access_group_relation.user_id}:#{user_access_group_relation.access_group_id}"
    Redix.command!(@redix, ["DEL", @namespace <> key])
  end

  defp from_json(json_string) do
    json_string
    |> Jason.decode!(keys: :atoms)
    |> (fn map -> struct(%UserAccessGroupRelation{}, map) end).()
  end
end
