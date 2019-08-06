defmodule DiscoveryApiWeb.DatasetGeoJsonController do
  use DiscoveryApiWeb, :controller

  alias DiscoveryApiWeb.Services.PrestoService

  def get_features(conn, _params) do
    if conn.assigns.model.sourceFormat == "geojson" do
      dataset_name = conn.assigns.model.name

      features = PrestoService.preview(dataset_name, 10)
      render(conn, "features.json", features: features, dataset_name: dataset_name)
    end
  end
end
