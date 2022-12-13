defmodule RaptorWeb.ApiKeyView do
  use RaptorWeb, :view

  def render("regenerateApiKey.json", %{apiKey: apiKey}) do
    %{
      apiKey: apiKey
    }
  end

  def render("isValidApiKey.json", %{is_valid_api_key: isValidApiKey}) do
    %{
      is_valid_api_key: isValidApiKey
    }
  end
end
