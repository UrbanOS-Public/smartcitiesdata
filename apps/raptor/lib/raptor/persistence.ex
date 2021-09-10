defmodule Raptor.Persistence do
  @moduledoc """
  This module provides functionality for interacting with Redis
  """

  alias Raptor.UserOrgAssoc

  @name_space "raptor:user_org_assoc:"
  @name_space_derived "raptor:derived:"
  @redix Raptor.Application.redis_client() # TODO define this in Application

  @doc """
  Get the `user org associations` saved in Redis under the given `user id`
  """
  @spec get(String.t()) :: map()
  def get(user_id) do
    case Redix.command!(@redix, ["GET", @name_space <> user_id]) do
      nil ->
        nil

      json ->
        from_json(json)
    end
  end

  @doc """
  Get all user-org associations from Redis
  """
  @spec get_all() :: list(map())
  def get_all() do
    IO.inspect(Redix.command!(@redix, ["KEYS", @name_space <> "*"]), label: "noodles")
    case Redix.command!(@redix, ["KEYS", @name_space <> "*"]) do
      [] ->
        []

      keys ->
        keys
        |> (fn keys -> Redix.command!(@redix, ["MGET" | keys]) end).()|> IO.inspect(label: "here")
        |> Enum.map(&from_json/1)
    end
  end

  @doc """
  Save a `Raptor.UserOrgAssoc` to Redis
  """
  @spec persist(Raptor.UserOrgAssoc.t()) :: Redix.Protocol.redis_value() | no_return()
  def persist(%UserOrgAssoc{} = user_org_assoc) do
    key = "#{user_org_assoc.user_id}_#{user_org_assoc.org_id}"
    user_org_assoc
    |> Map.from_struct()
    |> Jason.encode!()
    |> (fn assoc_json ->
          Redix.command!(@redix, ["SET", @name_space <> key, assoc_json])
        end).()
  end

   @doc """
  Remove a `Raptor.UserOrgAssoc` from Redis
  """
  @spec delete(Raptor.UserOrgAssoc.t()) :: Redix.Protocol.redis_value() | no_return()
  def delete(%UserOrgAssoc{} = user_org_assoc) do
    key = "#{user_org_assoc.user_id}_#{user_org_assoc.org_id}"
    user_org_assoc
    |> Map.from_struct()
    |> Jason.encode!()
    |> (fn assoc_json ->
          Redix.command!(@redix, ["DEL", @name_space <> key, assoc_json]) # TODOupdate implementation of this method to have delete capability
        end).()
  end

  defp from_json(json_string) do
    json_string
    |> Jason.decode!(keys: :atoms) |> IO.inspect(label: "jason decode")
    |> (fn map -> struct(%UserOrgAssoc{}, map) end).()
  end

end
