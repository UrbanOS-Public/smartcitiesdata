defmodule RaptorWeb.ApiKeyView do
  use RaptorWeb, :view

  def render("regenerateApiKey.json", %{apiKey: apiKey}) do
    %{
      apiKey: apiKey
    }
  end

  def render("getUserIdFromApiKey.json", %{user_id: user_id}) do
    %{
      user_id: user_id
    }
  end

  def render("checkRole.json", %{has_role: has_role}) do
    %{
      has_role: has_role
    }
  end
end
