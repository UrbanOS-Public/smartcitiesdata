defmodule RaptorWeb.ListAccessGroupsView do
  use RaptorWeb, :view

  def render("list.json", %{access_groups: access_groups}) do
    %{
      access_groups: access_groups
    }
  end
end
