defmodule DiscoveryApiWeb.DatasetGeoJsonControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApiWeb.Plugs.Acceptor
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Test.Helper

  describe "fetch geojson dataset" do
    test "retrieves geojson dataset", %{conn: conn} do
      dataset_name = "the_dataset"
      dataset_id = "the_dataset_id"
      row_limit = 10

      model = Helper.sample_model(%{id: dataset_id, name: dataset_name, sourceFormat: "geojson"})

      allow(Model.get(dataset_id), return: model)

      allow(DiscoveryApiWeb.Services.PrestoService.preview(dataset_name, row_limit),
        return: [%{"features" => "{}"}, %{"features" => "{}"}, %{"features" => "{}"}]
      )

      expected = %{
        "type" => "FeatureCollection",
        "name" => model.name,
        "features" => [%{}, %{}, %{}]
      }

      actual =
        conn
        |> put_resp_header("accepts", "application/geo+json")
        |> get("/api/v1/dataset/#{dataset_id}/features_preview")
        |> json_response(200)

      assert expected == actual
    end
  end
end
