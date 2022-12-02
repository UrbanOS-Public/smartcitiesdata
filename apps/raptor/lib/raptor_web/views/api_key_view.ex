defmodule RaptorWeb.ApiKeyView do
  use RaptorWeb, :view

  def render("regenerateApiKey.json", %{apiKey: apiKey}) do
    %{
      apiKey: apiKey
    }
  end
end
