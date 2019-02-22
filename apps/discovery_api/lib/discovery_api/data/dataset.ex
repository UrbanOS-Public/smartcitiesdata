defmodule DiscoveryApi.Data.Dataset do
  defstruct id: nil, title: nil, keywords: nil, organization: nil, modified: nil, fileTypes: nil, description: nil

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
    Jason.encode!(Map.from_struct(dataset))
    |> (fn dataset_json -> Redix.command(:redix, ["SET", @name_space <> dataset.id, dataset_json]) end).()
  end

  defp from_json(json_string) do
    Jason.decode!(json_string, keys: :atoms)
    |> (fn map -> struct(__MODULE__, map) end).()
  end
end
