defmodule Reaper.Persistence do
  @moduledoc false

  alias Reaper.ReaperConfig

  @name_space "reaper:reaper_config:"
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

  def persist(%ReaperConfig{} = reaper_config) do
    reaper_config
    |> Map.from_struct()
    |> Jason.encode!()
    |> (fn config_json -> Redix.command!(:redix, ["SET", @name_space <> reaper_config.dataset_id, config_json]) end).()
  end

  defp from_json(json_string) do
    json_string
    |> Jason.decode!(keys: :atoms)
    |> (fn map -> struct(%ReaperConfig{}, map) end).()
  end

  def record_last_fetched_timestamp(dataset_id, timestamp) do
    Redix.command(:redix, ["SET", @name_space_derived <> dataset_id, ~s({"timestamp": "#{timestamp}"})])
  end

  def get_last_fetched_timestamp(dataset_id) do
    json = Redix.command!(:redix, ["GET", @name_space_derived <> dataset_id])
    extract_timestamp(json)
  end

  defp extract_timestamp(nil), do: nil

  defp extract_timestamp(json) do
    {:ok, timestamp, _offset} =
      json
      |> Jason.decode!()
      |> Map.get("timestamp")
      |> DateTime.from_iso8601()

    timestamp
  end
end
