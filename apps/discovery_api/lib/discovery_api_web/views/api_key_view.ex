defmodule DiscoveryApiWeb.ApiKeyView do
  use DiscoveryApiWeb, :view

  def render("regenerateApiKey.json", %{apiKey: apiKey}) do
    %{
      apiKey: apiKey
    }
  end
end
