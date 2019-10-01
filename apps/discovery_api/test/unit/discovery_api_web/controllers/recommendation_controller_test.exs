defmodule DiscoveryApiWeb.RecommendationControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Data.Model

  @dataset_id "123"

  describe "/dataset/:dataset_id/recommendations" do
    test "retrieves stats for dataset when stats exist", %{conn: conn} do
      model = Helper.sample_model(%{id: @dataset_id})
      allow(Model.get(@dataset_id), return: model)
      mocked_response = [%{"id" => 1, "systemName" => "org__data_name"}]
      allow(DiscoveryApi.RecommendationEngine.get_recommendations(any()), return: mocked_response)

      actual = conn |> get("api/v1/dataset/#{@dataset_id}/recommendations") |> json_response(200)

      assert mocked_response == actual
    end
  end
end
