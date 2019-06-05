defmodule DiscoveryApi.Data.Persistence do
  @moduledoc """
  Module for communicating with Redis to persist and retrieve dataset information
  """
  def get_all(key_string) do
    :redix
    |> Redix.command!(["KEYS", key_string])
    |> get_items()
  end

  defp get_items([]), do: []

  defp get_items(keys) do
    :redix
    |> Redix.command!(["MGET" | keys])
    |> Enum.map(fn json -> Jason.decode!(json, keys: :atoms) end)
  end

  def get(key_string) do
    :redix
    |> Redix.command!(["GET", key_string])
  end

  def persist(key_string, value) when is_binary(value) do
    :redix
    |> Redix.command(["SET", key_string, value])
  end

  def persist(key_string, value_map) do
    :redix
    |> Redix.command(["SET", key_string, Jason.encode!(value_map)])
  end

  def get_keys(key_string) do
    :redix
    |> Redix.command!(["KEYS", key_string])
  end

  def get_many([]), do: []

  def get_many(keys) do
    :redix
    |> Redix.command!(["MGET" | keys])
  end
end
