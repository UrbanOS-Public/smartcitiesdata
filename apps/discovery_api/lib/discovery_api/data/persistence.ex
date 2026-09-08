defmodule DiscoveryApi.Data.Persistence do
  @moduledoc """
  Module for communicating with Redis to persist and retrieve dataset information
  """

  @redix_module Application.compile_env(:discovery_api, :redix_module, Redix)
  @scan_count 500

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
    @redix_module.command!(:redix, ["GET", key_string])
  end

  def persist(key_string, value) when is_binary(value) do
    @redix_module.command(:redix, ["SET", key_string, value])
  end

  def persist(key_string, value_map) do
    @redix_module.command(:redix, ["SET", key_string, Jason.encode!(value_map)])
  end

  def delete(key_string) do
    @redix_module.command(:redix, ["DEL", key_string])
  end

  # Uses SCAN instead of KEYS: KEYS blocks Redis for the duration of a full
  # keyspace scan, while SCAN walks the keyspace incrementally via a cursor.
  def get_keys(key_string) do
    scan_keys(key_string, "0", [])
  end

  defp scan_keys(pattern, cursor, acc) do
    case @redix_module.command!(:redix, ["SCAN", cursor, "MATCH", pattern, "COUNT", @scan_count]) do
      ["0", keys] -> acc ++ keys
      [next_cursor, keys] -> scan_keys(pattern, next_cursor, acc ++ keys)
    end
  end

  def get_many(keys, reject_nil \\ false)

  def get_many([], _reject_nil), do: []

  def get_many(keys, false) do
    @redix_module.command!(:redix, ["MGET" | keys])
  end

  def get_many(keys, true) do
    @redix_module.command!(:redix, ["MGET" | keys])
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
