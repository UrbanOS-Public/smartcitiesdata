defmodule DiscoveryApiWeb.Utilities.AccessUtils do
  @moduledoc """
  This behavior defines how access to datasets might be granted
  """
  @callback has_access?(%DiscoveryApi.Data.Model{}, binary()) :: boolean()
end
