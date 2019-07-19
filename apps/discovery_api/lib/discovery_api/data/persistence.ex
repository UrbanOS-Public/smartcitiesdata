defmodule DiscoveryApi.Data.Persistence do
  @moduledoc """
  Module for communicating with Redis to persist and retrieve dataset information
  """
  def get_all(key_string, reject_nil \\ false) do
    :redix
    |> Redix.command!(["KEYS", key_string])
    |> get_items(reject_nil)
  end

  defp get_items([], _), do: []

  defp get_items(keys, reject_nil) do
    :redix
    |> Redix.command!(["MGET" | keys])
    |> Enum.map(&safe_json_decode/1)
    |> Enum.reject(fn value -> reject_nil && is_nil(value) end)
  end

  defp safe_json_decode(json) do
    case json do
      nil -> nil
      decode -> Jason.decode!(decode, keys: :atoms)
    end
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

  def get_many(keys, reject_nil \\ false) do
    :redix
    |> Redix.command!(["MGET" | keys])
    |> Enum.reject(fn value -> reject_nil && is_nil(value) end)
  end
end
