defmodule DiscoveryApi.Data.Persistence do
  @moduledoc """
  Module for communicating with Redis to persist and retrieve dataset information
  """
  def get_all(key_string, reject_nil \\ false) do
    key_string
    |> get_keys()
    |> get_many(reject_nil)
  end

  def get(key_string) do
    Redix.command!(:redix, ["GET", key_string])
  end

  def persist(key_string, value) when is_binary(value) do
    Redix.command(:redix, ["SET", key_string, value])
  end

  def persist(key_string, value_map) do
    Redix.command(:redix, ["SET", key_string, Jason.encode!(value_map)])
  end

  def get_keys(key_string) do
    Redix.command!(:redix, ["KEYS", key_string])
  end

  def get_many(keys, reject_nil \\ false)

  def get_many([], _reject_nil), do: []

  def get_many(keys, reject_nil) do
    :redix
    |> Redix.command!(["MGET" | keys])
    |> Enum.reject(fn value -> reject_nil && is_nil(value) end)
  end
end
