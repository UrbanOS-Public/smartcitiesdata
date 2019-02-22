defmodule Reaper.Cache do
  @moduledoc false
  require Logger

  def dedupe(messages, cache_name) do
    Enum.filter(messages, fn message -> is_not_cached(message, cache_name) end)
  end

  def cache(messages, cache_name) do
    Enum.each(messages, fn result -> add_to_cache(result, cache_name) end)
    messages
  end

  defp is_not_cached(value, cache) do
    {:ok, result} = Cachex.exists?(cache, md5(Jason.encode!(value)))
    not result
  end

  defp add_to_cache({:ok, value}, cache), do: Cachex.put(cache, md5(Jason.encode!(value)), true)

  defp add_to_cache({:error, reason}, _cache) do
    Logger.warn("Unable to write message to Kafka topic: #{inspect(reason)}")
  end

  defp md5(thing) do
    :crypto.hash(:md5, thing) |> Base.encode16()
  end
end
