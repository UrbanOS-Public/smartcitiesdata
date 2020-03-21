defmodule DiscoveryApi.Search.DataModelSearchinator do
  @moduledoc """
  Returns datasets that match the passed in query.
  """
  alias DiscoveryApi.Data.Model

  def search(query \\ "")

  def search("") do
    Model.get_all()
  end

  def search(query) do
    DiscoveryApi.Search.Storage.search(query)
  end
end
