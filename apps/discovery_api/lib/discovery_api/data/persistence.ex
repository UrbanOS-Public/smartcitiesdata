defmodule DiscoveryApi.Data.Persistence do
  @moduledoc false
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
    |> map_from_json()
  end

  defp map_from_json(nil), do: nil

  defp map_from_json(json) do
    Jason.decode!(json, keys: :atoms)
  end

  def persist(key_string, value_map) do
    :redix
    |> Redix.command(["SET", key_string, Jason.encode!(value_map)])
  end
end
