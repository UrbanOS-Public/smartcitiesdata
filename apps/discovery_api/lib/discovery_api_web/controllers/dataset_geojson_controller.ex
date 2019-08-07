defmodule DiscoveryApiWeb.DatasetGeoJsonController do
  use DiscoveryApiWeb, :controller

  alias DiscoveryApiWeb.Services.PrestoService

  def get_features(conn, _params) do
    dataset_name = conn.assigns.model.name

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
    feature
    |> Map.get("features")
    |> Jason.decode!()
  end
end
