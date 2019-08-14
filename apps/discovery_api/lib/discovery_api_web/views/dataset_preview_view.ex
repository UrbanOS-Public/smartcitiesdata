defmodule DiscoveryApiWeb.DatasetPreviewView do
  use DiscoveryApiWeb, :view

  def render("features.json", %{features: features, dataset_name: name, bbox: bbox}) do
    %{
      name: name,
      features: features,
      bbox: bbox,
      type: "FeatureCollection"
    }
  end
end
