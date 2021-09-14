defmodule Raptor.Services.DatasetStore do
  @moduledoc """
  This module provides functionality for interacting with Redis
  """
  require Logger
  alias Raptor.Schemas.Dataset

  @namespace "raptor:datasets:"
  @redix Raptor.Application.redis_client()

  @doc """
  Get all datasets from Redis
  """
  @spec get_all() :: list(map())
  def get_all() do
    case Redix.command!(@redix, ["KEYS", @namespace <> "*"]) do
      [] ->
        []

      keys ->
        keys
        |> (fn keys -> Redix.command!(@redix, ["MGET" | keys]) end).()
        |> IO.inspect(label: "******** HERE IS THE JSON YOU ARE LOOKING FOR *********")
        |> Enum.map(&from_json/1)
    end
  end

  @doc """
  Get a given dataset by its system name
  """
  @spec get(String.t()) :: map()
  def get(system_name) do
    entries_matching_system_name = Redix.command!(@redix, ["KEYS", @namespace <> system_name])

    case length(entries_matching_system_name) do
      0 ->
        Logger.warn("No datasets exist with system name of #{system_name}")
        %{}

      1 ->
        dataset_key = entries_matching_system_name |> List.first()
        Redix.command!(@redix, ["MGET", dataset_key]) |> Enum.map(&from_json/1) |> List.first()

      _ ->
        Logger.warn("Multiple datasets match #{system_name}. Cannot continue.")
        %{}
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
