defmodule Reaper.Cache do
  @moduledoc """
  Cache module for rows of data before it is added to the raw topic
  """
  require Logger
  
  @behaviour Reaper.CacheBehaviour
  
  @json_encoder Application.compile_env(:reaper, :json_encoder, Jason)

  defmodule CacheError do
    defexception [:message]
  end

  def child_spec(opts) do
    name = Keyword.fetch!(opts, :name)

    %{
      id: name,
      start: {Reaper.Cache.Server, :start_link, [[name: via(name)]]}
    }
  end

  @doc """
  Returns a tuple for a value that signifies if it exists in the cache
  """
  @spec mark_duplicates(atom(), any()) :: {:ok, any()} | {:duplicate, any()} | {:error, any()}
  def mark_duplicates(cache, value) do
    value
    |> format_key()
    |> exists?(cache)
    |> to_result(value)
  end

  @doc """
  Adds a value to the cache
  """
  @spec cache(atom(), any()) :: {:ok, boolean()} | {:error, any()}
  def cache(cache, value) do
    value
    |> format_key()
    |> put_in_cache(cache)
  end

  defp put_in_cache({:ok, key}, cache) do
    GenServer.cast(via(cache), {:put, key})
    {:ok, true}
  end

  defp put_in_cache({:error, _} = error, _cache), do: error

  defp exists?({:ok, key}, cache) do
    {:ok, GenServer.call(via(cache), {:exists?, key})}
  end

  defp exists?({:error, _} = error, _cache), do: error

  defp to_result({:ok, false}, value), do: {:ok, value}
  defp to_result({:ok, true}, value), do: {:duplicate, value}
  defp to_result({:error, _} = error, _value), do: error

  defp format_key(value) do
    case @json_encoder.encode(value) do
      {:ok, value} -> {:ok, md5(value)}
      {:error, reason} -> {:error, {:json, reason}}
    end
  end

  defp md5(thing) do
    :crypto.hash(:md5, thing) |> Base.encode16()
  end

  defp via(name) do
    {:via, Horde.Registry, {Reaper.Cache.Registry, name}}
  end
end
