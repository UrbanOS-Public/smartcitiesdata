defmodule Reaper.Persistence do
  @moduledoc false

  alias Reaper.Sickle

  @name_space "reaper:dataset:"
  @name_space_derived "reaper:derived:"

  def get(dataset_id) do
    case Redix.command!(:redix, ["GET", @name_space <> dataset_id]) do
      nil ->
        nil

      json ->
        from_json(json)
    end
  end

  def get_all() do
    case Redix.command!(:redix, ["KEYS", @name_space <> "*"]) do
      [] ->
        []

      keys ->
        keys
        |> (fn keys -> Redix.command!(:redix, ["MGET" | keys]) end).()
        |> Enum.map(&from_json/1)
    end
  end

  def persist(%Sickle{} = dataset) do
    dataset
    |> Map.from_struct()
    |> Jason.encode!()
    |> (fn dataset_json -> Redix.command!(:redix, ["SET", @name_space <> dataset.dataset_id, dataset_json]) end).()
  end

  defp from_json(json_string) do
    json_string
    |> Jason.decode!(keys: :atoms)
    |> (fn map -> struct(%Sickle{}, map) end).()
  end

  def record_last_fetched_timestamp([_ | _] = records, dataset_id, timestamp) do
    success = Enum.any?(records, fn {status, _} -> status == :ok end)

    if success do
      Redix.command(:redix, ["SET", @name_space_derived <> dataset_id, "{\"timestamp\": \"#{timestamp}\"}"])
    end
  end

  def record_last_fetched_timestamp(_records, _dataset_id, _timestamp), do: nil
end
