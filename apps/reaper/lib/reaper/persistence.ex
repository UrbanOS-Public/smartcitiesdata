defmodule Reaper.Persistence do
  @moduledoc """
  This module provides functionality for interacting with Redis
  """

  alias Reaper.ReaperConfig

  @name_space "reaper:reaper_config:"
  @name_space_derived "reaper:derived:"

  @doc """
  Get the `Reaper.ReaperConfig` saved in Redis under the given `dataset_id`
  """
  @spec get(String.t()) :: map()
  def get(dataset_id) do
    case Redix.command!(:redix, ["GET", @name_space <> dataset_id]) do
      nil ->
        nil

      json ->
        from_json(json)
    end
  end

  @doc """
  Get all `Reaper.ReaperConfig`s from Redis
  """
  @spec get_all() :: list(map())
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

  @doc """
  Save a `Reaper.ReaperConfig` to Redis
  """
  @spec persist(ReaperConfig.t()) :: Redix.Protocol.redis_value() | no_return()
  def persist(%ReaperConfig{} = reaper_config) do
    reaper_config
    |> Map.from_struct()
    |> Jason.encode!()
    |> (fn config_json ->
          Redix.command!(:redix, ["SET", @name_space <> reaper_config.dataset_id, config_json])
        end).()
  end

  defp from_json(json_string) do
    json_string
    |> Jason.decode!(keys: :atoms)
    |> (fn map -> struct(%ReaperConfig{}, map) end).()
  end

  @doc """
  Update the timestamp of when data was last fetched for a dataset_id in Redis
  """
  @spec record_last_fetched_timestamp(String.t(), DateTime.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def record_last_fetched_timestamp(dataset_id, timestamp) do
    Redix.command(:redix, [
      "SET",
      @name_space_derived <> dataset_id,
      ~s({"timestamp": "#{timestamp}"})
    ])
  end

  def get_last_processed_index(dataset_id) do
    case Redix.command!(:redix, ["GET", "reaper:#{dataset_id}:last_processed_index"]) do
      nil -> -1
      last_processed_index -> String.to_integer(last_processed_index)
    end
  end

  def record_last_processed_index(dataset_id, index) do
    Redix.command!(:redix, ["SET", "reaper:#{dataset_id}:last_processed_index", index])
  end

  def remove_last_processed_index(dataset_id) do
    Redix.command!(:redix, ["DEL", "reaper:#{dataset_id}:last_processed_index"])
  end

  @doc """
  Retrieve the timestamp of when data was last fetched for a dataset_id from Redis
  """
  @spec get_last_fetched_timestamp(String.t()) :: DateTime.t() | nil
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
