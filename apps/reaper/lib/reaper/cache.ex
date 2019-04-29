defmodule Reaper.Cache do
  @moduledoc false
  require Logger

  def duplicate?(value, cache) do
    {:ok, result} = Cachex.exists?(cache, format_key(value))
    result
  end

  def cache(messages, cache_name) do
    Stream.map(messages, fn result ->
      add_to_cache(result, cache_name)
      result
    end)
  end

  defp add_to_cache({:ok, value}, cache), do: Cachex.put(cache, format_key(value), true)

  defp add_to_cache({:error, reason}, _cache) do
    Logger.warn("Unable to write message to Kafka topic: #{inspect(reason)}")
  end

  defp format_key(message) do
    message
    |> Jason.encode!()
    |> md5()
  end

  defp md5(thing) do
    :crypto.hash(:md5, thing) |> Base.encode16()
  end
end
