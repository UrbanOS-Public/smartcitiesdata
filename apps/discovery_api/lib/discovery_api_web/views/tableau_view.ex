defmodule DiscoveryApiWeb.TableauView do
  use DiscoveryApiWeb, :view

  def render("fetch_table_info.json", %{table_infos: table_infos}) do
    table_infos
  end
end
