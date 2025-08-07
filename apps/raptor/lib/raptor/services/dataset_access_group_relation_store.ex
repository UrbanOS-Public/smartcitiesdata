defmodule Raptor.Services.DatasetAccessGroupRelationStore do
  @behaviour Raptor.Services.DatasetAccessGroupRelationStoreBehaviour
  @moduledoc """
  This module provides functionality for interacting with Redis
  """
  require Logger
  alias Raptor.Schemas.DatasetAccessGroupRelation

  @namespace "raptor:dataset_access_group_relation:"
  @redix Raptor.Application.redis_client()

  @doc """
  Get all dataset access group relations from Redis
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
  Get all access groups from Redis for a specific dataset
  """
  @spec get_all_by_dataset(String.t()) :: list(map())
  def get_all_by_dataset(dataset_id) do
    case Redix.command!(@redix, ["KEYS", @namespace <> dataset_id <> ":*"]) do
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
  Get a given dataset-access_group relation
  """
  @spec get(String.t(), String.t()) :: map()
  def get(dataset_id, access_group_id) do
    key = "#{dataset_id}:#{access_group_id}"
    matching_entries = Redix.command!(@redix, ["KEYS", @namespace <> key])

    case length(matching_entries) do
      0 ->
        Logger.warn(
          "No dataset access group relations exist with dataset_id #{dataset_id} and access_group_id #{access_group_id}"
        )

        %{}

      1 ->
        assoc_key = matching_entries |> List.first()
        Redix.command!(@redix, ["MGET", assoc_key]) |> Enum.map(&from_json/1) |> List.first()

      _ ->
        Logger.warn(
          "Multiple dataset-access_group relations match #{dataset_id}:#{access_group_id}. Cannot continue."
        )

        %{}
    end
  end

  @doc """
  Save a `Raptor.Schemas.DatasetAccessGroupRelation` to Redis
  """
  @spec persist(Raptor.Schemas.DatasetAccessGroupRelation.t()) ::
          Redix.Protocol.redis_value() | no_return()
  def persist(%DatasetAccessGroupRelation{} = dataset_access_group_relation) do
    key =
      "#{dataset_access_group_relation.dataset_id}:#{dataset_access_group_relation.access_group_id}"

    dataset_access_group_relation
    |> Map.from_struct()
    |> Jason.encode!()
    |> (fn assoc_json ->
          Redix.command!(@redix, ["SET", @namespace <> key, assoc_json])
        end).()
  end

  @doc """
  Remove a `Raptor.Schemas.DatasetAccessGroupRelation` from Redis
  """
  @spec delete(Raptor.Schemas.DatasetAccessGroupRelation.t()) ::
          Redix.Protocol.redis_value() | no_return()
  def delete(%DatasetAccessGroupRelation{} = dataset_access_group_relation) do
    key =
      "#{dataset_access_group_relation.dataset_id}:#{dataset_access_group_relation.access_group_id}"

    Redix.command!(@redix, ["DEL", @namespace <> key])
  end

  defp from_json(json_string) do
    json_string
    |> Jason.decode!(keys: :atoms)
    |> (fn map -> struct(%DatasetAccessGroupRelation{}, map) end).()
  end
end
