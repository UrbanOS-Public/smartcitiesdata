defmodule Raptor.Services.DatasetStore do
  @behaviour Raptor.Services.DatasetStoreBehaviour
  @moduledoc """
  This module provides functionality for interacting with Redis
  """
  require Logger
  alias Raptor.Schemas.Dataset
  alias Raptor.Services.RedisKeyScanner

  @namespace "raptor:datasets:"
  @redix Raptor.Application.redis_client()

  @doc """
  Get all datasets from Redis
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
  Get a given dataset by its system name
  """
  @spec get(String.t()) :: map()
  def get(system_name) do
    case Redix.command!(@redix, ["GET", @namespace <> system_name]) do
      nil ->
        Logger.warn("No datasets exist with system name of #{system_name}")
        %{}

      dataset_json ->
        from_json(dataset_json)
    end
  end

  @doc """
  Save a `Raptor.Schemas.Dataset` to Redis
  """
  @spec persist(Raptor.Schemas.Dataset.t()) :: Redix.Protocol.redis_value() | no_return()
  def persist(%Dataset{} = dataset) do
    dataset
    |> Map.from_struct()
    |> Jason.encode!()
    |> (fn dataset_json ->
          Redix.command!(@redix, ["SET", @namespace <> dataset.system_name, dataset_json])
        end).()
  end

  defp from_json(json_string) do
    json_string
    |> Jason.decode!(keys: :atoms)
    |> (fn map -> struct(%Raptor.Schemas.Dataset{}, map) end).()
  end
end
