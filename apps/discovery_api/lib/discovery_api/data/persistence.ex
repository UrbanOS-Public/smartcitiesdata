defmodule DiscoveryApi.Data.Persistence do
  @moduledoc """
  Module for communicating with Redis to persist and retrieve dataset information
  """
  def get_all(key_string, reject_nil \\ false) do
    key_string
    |> get_keys()
    |> get_many(reject_nil)
  end

  def get_all_with_keys(key_string) do
    key_string
    |> get_keys()
    |> get_many_with_keys()
    |> Map.new()
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

  def get_many(keys, false) do
    Redix.command!(:redix, ["MGET" | keys])
  end

  def get_many(keys, true) do
    Redix.command!(:redix, ["MGET" | keys])
    |> Enum.reject(&is_nil/1)
  end

  def get_many_with_keys(keys) do
    values =
      keys
      |> get_many()
      |> Enum.map(&decode_if_json/1)

    Enum.zip(keys, values)
    |> Enum.into(%{})
  end

  defp decode_if_json(nil), do: nil

  defp decode_if_json(value) do
    case Jason.decode(value) do
      {:ok, decoded} -> decoded
      {:error, _reason} -> value
    end
  end
end
