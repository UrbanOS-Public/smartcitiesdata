defmodule Reaper.Cache do
  @moduledoc false
  require Logger

  @spec mark_duplicates(atom(), any()) :: {:ok, any()} | {:duplicate, any()} | {:error, any()}
  def mark_duplicates(cache, value) do
    value
    |> format_key()
    |> exists?(cache)
    |> to_result(value)
  end

  @spec cache(atom(), any()) :: {:ok, boolean()} | {:error, any()}
  def cache(cache, value) do
    value
    |> format_key()
    |> put_in_cache(cache)
  end

  defp put_in_cache({:ok, key}, cache) do
    case Cachex.put(cache, key, true) do
      {:error, reason} -> {:error, {:cachex, reason}}
      result -> result
    end
  end

  defp put_in_cache({:error, _} = error, _cache), do: error

  defp exists?({:ok, key}, cache) do
    case Cachex.exists?(cache, key) do
      {:error, reason} -> {:error, {:cachex, reason}}
      result -> result
    end
  end

  defp exists?({:error, _} = error, _cache), do: error

  defp to_result({:ok, false}, value), do: {:ok, value}
  defp to_result({:ok, true}, value), do: {:duplicate, value}
  defp to_result({:error, _} = error, _value), do: error

  defp format_key(value) do
    case Jason.encode(value) do
      {:ok, value} -> {:ok, md5(value)}
      {:error, reason} -> {:error, {:json, reason}}
    end
  end

  defp md5(thing) do
    :crypto.hash(:md5, thing) |> Base.encode16()
  end
end
