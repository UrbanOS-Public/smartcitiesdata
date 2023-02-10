defmodule Raptor.Services.Auth0UserDataStore do
  @moduledoc """
  This module provides functionality for interacting with Redis
  """
  require Logger
  alias Raptor.Schemas.Auth0UserData

  @namespace "raptor:auth0_user_data:"
  @redix Raptor.Application.redis_client()

  @doc """
  Get Auth0 user data from Redis for a specific user
  """
  @spec get_user_by_api_key(String.t()) :: list(map())
  def get_user_by_api_key(api_key) do
    case Redix.command!(@redix, ["KEYS", @namespace <> api_key]) do
      [] ->
        []

      keys ->
        keys
        |> (fn keys -> Redix.command!(@redix, ["MGET" | keys]) end).()
        |> Enum.map(&from_json/1)
    end
  end

  @doc """
  Save a `Raptor.Schemas.Auth0UserData` to Redis
  """
  @spec persist(Raptor.Schemas.Auth0UserData.t()) ::
          Redix.Protocol.redis_value() | no_return()
  def persist(%Auth0UserData{} = auth0_user_data) do
    key = auth0_user_data.app_metadata.apiKey

    auth0_user_data
    |> Map.from_struct()
    |> Jason.encode!()
    |> (fn assoc_json ->
          Redix.command!(@redix, ["SET", @namespace <> key, assoc_json, "EX", "3600"])
        end).()
  end

  @doc """
  Remove a `Raptor.Schemas.Auth0UserData` from Redis
  """
  @spec delete_by_api_key(String.t()) ::
          Redix.Protocol.redis_value() | no_return()
  def delete_by_api_key(api_key) do
    key = "#{api_key}"
    Redix.command!(@redix, ["DEL", @namespace <> key])
  end

  defp from_json(json_string) do
    json_string
    |> Jason.decode!(keys: :atoms)
    |> (fn map -> struct(%Auth0UserData{}, map) end).()
  end
end
