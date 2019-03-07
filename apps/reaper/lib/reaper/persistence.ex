defmodule Reaper.Persistence do
  @moduledoc false

  @name_space "reaper:dataset:"

  def get(id) do
    case Redix.command!(:redix, ["GET", "reaper:dataset:#{id}"]) do
      nil ->
        nil

      json ->
        {:ok, dataset} = SCOS.RegistryMessage.new(json)
        dataset
    end
  end

  def get_all() do
    case Redix.command!(:redix, ["KEYS", @name_space <> "*"]) do
      [] ->
        []

      keys ->
        keys
        |> (fn keys -> Redix.command!(:redix, ["MGET" | keys]) end).()
        |> Enum.map(&SCOS.RegistryMessage.new/1)
        |> Enum.map(fn {:ok, value} -> value end)
    end
  end

  def persist(%SCOS.RegistryMessage{} = dataset) do
    dataset
    |> Map.from_struct()
    |> Jason.encode!()
    |> (fn dataset_json -> Redix.command!(:redix, ["SET", @name_space <> dataset.id, dataset_json]) end).()
  end
end
