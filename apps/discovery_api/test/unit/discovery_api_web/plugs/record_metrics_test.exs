defmodule DiscoveryApiWeb.Plugs.RecordMetricsTest do
  use DiscoveryApiWeb.ConnCase
  import Mox
  alias DiscoveryApiWeb.Plugs.RecordMetrics
  alias DiscoveryApi.Test.Helper

  setup :verify_on_exit!
  setup :set_mox_from_context

  def run_test(allowed_origin, action, expected_label) do
    dataset_id = 1111
    model = Helper.sample_model(%{id: dataset_id})

    # Set up expectation for the MetricsService call
    expect(MetricsServiceMock, :record_api_hit, fn label, id ->
      assert label == expected_label
      assert id == dataset_id
      :ok
    end)

    conn =
      build_conn(:get, "/organization/:org_name/dataset/#{dataset_id}/download")
      |> assign(:model, model)
      |> assign(:allowed_origin, allowed_origin)
      |> put_private(:phoenix_action, action)

    RecordMetrics.call(conn, fetch_file: "downloads", query: "queries")
    
    # Give the Task time to complete
    Process.sleep(100)
  end

  describe "call/2 records metrics" do
    @tag timeout: 1000
    test "when allowed origin is false" do
      run_test(false, :fetch_file, "downloads")
    end

    @tag timeout: 1000
    test "when allowed origin is nil" do
      run_test(nil, :fetch_file, "downloads")
    end

    @tag timeout: 1000
    test "and converts query action to the label 'queries'" do
      run_test(nil, :query, "queries")
    end
  end

  describe "call/2 does not records metrics" do
    @tag timeout: 1000
    test "when allowed origin is true" do
      dataset_id = 1111
      model = Helper.sample_model(%{id: dataset_id})

      # Don't set up any expectations - if MetricsService is called, Mox will fail
      # No expectation means the call should not happen

      conn =
        build_conn(:get, "/organization/:org_name/dataset/#{dataset_id}/download")
        |> assign(:model, model)
        |> assign(:allowed_origin, true)
        |> put_private(:phoenix_action, :fetch_file)

      RecordMetrics.call(conn, fetch_file: "downloads", query: "queries")
      
      # Give time for any potential Task to complete
      Process.sleep(100)
      
      # If we reach here without Mox failing, the test passes
    end
  end
end
