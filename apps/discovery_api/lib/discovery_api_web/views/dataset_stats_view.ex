defmodule DiscoveryApiWeb.DatasetStatsView do
  @moduledoc """
  View for rendering dataset stats/completeness
  """
  use DiscoveryApiWeb, :view

  def render("fetch_dataset_stats.json", %{model: model}) do
    model
  end
end
