defmodule DiscoveryApi.Data.Dataset do
  @moduledoc """
  dataset utilities to persist and load.
  """
  alias DiscoveryApi.Data.Persistence

  defstruct [
    :id,
    :title,
    :keywords,
    :organization,
    :modified,
    :fileTypes,
    :description,
    :systemName,
    :sourceUrl,
    :sourceType
  ]

  @name_space "discovery-api:dataset:"

  def get_all() do
    (@name_space <> "*")
    |> Persistence.get_all()
    |> Enum.map(&struct_from_map/1)
  end

  def get(id) do
    (@name_space <> id)
    |> Persistence.get()
    |> struct_from_map
  end

  def save(%__MODULE__{} = dataset) do
    Persistence.persist(@name_space <> dataset.id, Map.from_struct(dataset))
  end

  defp struct_from_map(nil), do: nil

  defp struct_from_map(map) do
    struct(__MODULE__, map)
  end
end
