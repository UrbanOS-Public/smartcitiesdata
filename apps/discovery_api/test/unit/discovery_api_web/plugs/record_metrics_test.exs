defmodule DiscoveryApiWeb.Plugs.RecordMetricsTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApiWeb.Plugs.RecordMetrics
  alias DiscoveryApi.Services.MetricsService
  alias DiscoveryApi.Test.Helper

  def run_test(allowed_origin, action \\ :fetch_file) do
    dataset_id = 1111
    model = Helper.sample_model(%{id: dataset_id})

    conn =
      build_conn(:get, "/organization/:org_name/dataset/#{dataset_id}/download")
      |> assign(:model, model)
      |> assign(:allowed_origin, allowed_origin)
      |> put_private(:phoenix_action, action)

    allow(MetricsService.record_api_hit(any(), any()), return: conn)

    RecordMetrics.call(conn, fetch_file: "downloads", query: "queries")
  end

  describe "call/2 records metrics" do
    test "when allowed origin is false" do
      run_test(false)
      assert_called(MetricsService.record_api_hit("downloads", any()))
    end

    test "when allowed origin is nil" do
      run_test(nil)
      assert_called(MetricsService.record_api_hit("downloads", any()))
    end

    test "and converts query action to the label 'queries'" do
      run_test(nil, :query)
      assert_called(MetricsService.record_api_hit("queries", any()))
    end
  end

  describe "call/2 does not records metrics" do
    test "when allowed origin is true" do
      run_test(true)
      refute_called(MetricsService.record_api_hit("downloads", any()))
    end
  end
end
