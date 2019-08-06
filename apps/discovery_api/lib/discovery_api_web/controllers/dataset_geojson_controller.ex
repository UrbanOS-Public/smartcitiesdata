defmodule DiscoveryApiWeb.DatasetGeoJsonController do
  use DiscoveryApiWeb, :controller

  alias DiscoveryApiWeb.Services.PrestoService

  def get_features(conn, _params) do
    # change this to conn.assigns.model.name
    dataset_name = "geojson_table"

    features =
      PrestoService.preview(dataset_name, 10)
      |> decode_presto_results()

    render(conn, "features.json", features: features, dataset_name: dataset_name)
  end

  defp decode_presto_results(features_list) do
    features_list
    |> Enum.map(&decode_feature_result(&1))
  end

  defp decode_feature_result(feature) do
    Map.update!(feature, "features", &Jason.decode!(&1))
  end
end
