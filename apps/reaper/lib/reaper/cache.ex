defmodule Reaper.Cache do
  @moduledoc false
  require Logger

  def duplicate?(value, cache) do
    {:ok, result} = Cachex.exists?(cache, format_key(value))
    result
  end

  def cache(cache, {:ok, value}) do
    Cachex.put(cache, format_key(value), true)
  end

  def cache(_cache, {:error, _}) do
    nil
  end

  defp format_key(value) do
    value
    |> Jason.encode!()
    |> md5()
  end

  defp md5(thing) do
    :crypto.hash(:md5, thing) |> Base.encode16()
  end
end
