defmodule RaptorWeb.AuthorizeView do
  use RaptorWeb, :view

  def render("authorize.json", %{is_authorized: auth}) do
    %{
      is_authorized: auth
    }
  end
end
