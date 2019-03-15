defmodule DiscoveryApi.Data.ProjectOpenData do
  @moduledoc """
  Utilities to load the Open Metadata Schema data of a dataset.
  """
  alias DiscoveryApi.Data.Persistence
  defstruct [:id, :title, :keywords, :organization, :modified, :fileTypes, :description]

  @name_space "discovery-api:project-open-data:"

  def get_all() do
    Persistence.get_all(@name_space <> "*")
  end

  defp struct_from_map(nil) do
    nil
  end

  defp struct_from_map(map) do
    struct(__MODULE__, map)
  end
end
