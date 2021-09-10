defmodule Raptor.Persistence do
  @moduledoc """
  This module provides functionality for interacting with Redis
  """

  alias Raptor.UserOrgAssoc
  alias Raptor.Dataset

  @name_space "raptor:user_org_assoc:"
  @name_space_datasets "raptor:datasets:"
  @redix Raptor.Application.redis_client()

  @doc """
  Get all entries of a given type from Redis
  """
  @spec get_all_user_org_assocs() :: list(map())
  def get_all_user_org_assocs() do
    case Redix.command!(@redix, ["KEYS", @name_space <> "*"]) do
      [] ->
        []

      keys ->
        keys
        |> (fn keys -> Redix.command!(@redix, ["MGET" | keys]) end).()|> IO.inspect(label: "here")
        |> Enum.map(&from_json_for_user_org_assoc/1)
    end
  end

    @doc """
  Get all entries of a given type from Redis
  """
  @spec get_all_datasets() :: list(map())
  def get_all_datasets() do
    case Redix.command!(@redix, ["KEYS", @name_space_datasets <> "*"]) do
      [] ->
        []

      keys ->
        keys
        |> (fn keys -> Redix.command!(@redix, ["MGET" | keys]) end).()|> IO.inspect(label: "here")
        |> Enum.map(&from_json_for_datasets/1)
    end
  end

  @doc """
  Save a `Raptor.UserOrgAssoc` to Redis
  """
  @spec persist(Raptor.UserOrgAssoc.t()) :: Redix.Protocol.redis_value() | no_return()
  def persist(%UserOrgAssoc{} = user_org_assoc) do
    key = "#{user_org_assoc.user_id}:#{user_org_assoc.org_id}"
    user_org_assoc
    |> Map.from_struct()
    |> Jason.encode!()
    |> (fn assoc_json ->
          Redix.command!(@redix, ["SET", @name_space <> key, assoc_json])
        end).()
  end

  @doc """
  Save a `Raptor.Dataset` to Redis
  """
  @spec persist(Raptor.Dataset.t()) :: Redix.Protocol.redis_value() | no_return()
  def persist(%Dataset{} = dataset) do
    dataset
    |> Map.from_struct()
    |> Jason.encode!()
    |> (fn dataset_json ->
          Redix.command!(@redix, ["SET", @name_space_datasets <> dataset.system_name, dataset_json])
        end).()
  end

   @doc """
  Remove a `Raptor.UserOrgAssoc` from Redis
  """
  @spec delete(Raptor.UserOrgAssoc.t()) :: Redix.Protocol.redis_value() | no_return()
  def delete(%UserOrgAssoc{} = user_org_assoc) do
    key = "#{user_org_assoc.user_id}:#{user_org_assoc.org_id}"
    user_org_assoc
    |> Map.from_struct()
    |> Jason.encode!()
    |> (fn assoc_json ->
          Redix.command!(@redix, ["DEL", @name_space <> key, assoc_json])
        end).()
  end

  defp from_json_for_user_org_assoc(json_string) do
    json_string
    |> Jason.decode!(keys: :atoms) |> IO.inspect(label: "jason decode")
    |> (fn map -> struct(%UserOrgAssoc{}, map) end).()
  end

   defp from_json_for_datasets(json_string) do
    json_string
    |> Jason.decode!(keys: :atoms) |> IO.inspect(label: "jason decode")
    |> (fn map -> struct(%Raptor.Dataset{}, map) end).()
  end

end
