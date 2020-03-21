defmodule DiscoveryApiWeb.Plugs.SetAllowedOriginTest do
  use DiscoveryApiWeb.ConnCase
  alias DiscoveryApiWeb.Plugs.SetAllowedOrigin

  def run_test(host_origin) do
    conn =
      build_conn(:get, "/organization/:org_name/dataset/:dataset/download")
      |> put_req_header("origin", host_origin)

    %{assigns: %{allowed_origin: actual}} = SetAllowedOrigin.call(conn, [])
    actual
  end

  describe "call/2 sets allowed origin to true" do
    test "when origin's domain matches" do
      assert true == run_test("data.tests.example.com")
    end

    test "when full origin matches" do
      assert true == run_test("tests.example.com")
    end
  end

  describe "call/2 sets allowed origin to false" do
    test "when not present in env variable" do
      assert false == run_test("invalid.com")
    end

    test "when subdomain partial matches" do
      assert false == run_test("mytests.example.com")
    end
  end

  describe "call/2 sets allowed origin to nil" do
    test "when origin does not exist" do
      conn = build_conn(:get, "/organization/:org_name/dataset/:dataset/download")

      %{assigns: %{allowed_origin: actual}} = SetAllowedOrigin.call(conn, [])
      assert nil == actual
    end

    test "when origin is null" do
      assert nil == run_test("null")
    end
  end
end
