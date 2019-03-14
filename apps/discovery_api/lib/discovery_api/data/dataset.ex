defmodule DiscoveryApi.Data.Dataset do
  @moduledoc """
  dataset utilities to persist and load.
  """
  defstruct [:id, :title, :keywords, :organization, :modified, :fileTypes, :description]

  @name_space "discovery-api:dataset:"

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

  def get(id) do
    Redix.command!(:redix, ["GET", @name_space <> id])
    |> from_json
  end

  def save(%__MODULE__{} = dataset) do
    dataset
    |> Map.from_struct()
    |> Jason.encode!()
    |> (fn dataset_json ->
          Redix.command(:redix, ["SET", @name_space <> dataset.id, dataset_json])
        end).()
  end

  defp from_json(nil) do
    nil
  end

  defp from_json(json_string) do
    json_string
    |> Jason.decode!(keys: :atoms)
    |> (fn map -> struct(__MODULE__, map) end).()
  end
end
