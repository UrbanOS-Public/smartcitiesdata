defmodule Forklift.CacheClient do
  @moduledoc false

  @data_name_space "forklift:dataset"
  @cache_processing_batch_size Application.get_env(:forklift, :cache_processing_batch_size)

  def write(message, dataset_id, offset) do
    key = "#{@data_name_space}:#{dataset_id}:#{offset}"
    Redix.command!(:redix, ["SET", key, message])
  end

  def read_all_batched_messages() do
    Redix.command!(:redix, [
      "SCAN",
      0,
      "MATCH",
      "#{@data_name_space}:*",
      "COUNT",
      @cache_processing_batch_size
    ])
    |> Enum.at(1)
    |> Enum.map(fn key ->
      {key, Redix.command!(:redix, ["GET", key])}
    end)
  end

  def delete(keys) when is_list(keys) do
    Redix.command!(:redix, ["DEL" | keys])
  end

  def delete(key) do
    Redix.command!(:redix, ["DEL", key])
  end
end
