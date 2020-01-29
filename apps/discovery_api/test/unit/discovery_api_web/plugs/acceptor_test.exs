defmodule DiscoveryApiWeb.Plugs.AcceptorTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApiWeb.Plugs.Acceptor

  describe "call/2" do
    test "parses file extensions from the accept header" do
      conn =
        build_conn(:get, "/doesnt/matter")
        |> put_req_header("accept", "application/geo+json")

      %{private: %{phoenix_format: format}} = Acceptor.call(conn, [])

      assert ["geojson"] == format
    end

    test "parses file extensions from the query params" do
      conn = build_conn(:get, "/doesnt/matter?_format=json", %{})

      %{private: %{phoenix_format: format}} = Acceptor.call(conn, [])

      assert ["json"] == format
    end

    test "parses file extensions from the query params even if an accept header is sent" do
      conn =
        build_conn(:get, "/doesnt/matter?_format=json", %{})
        |> put_req_header("accept", "application/geo+json")

      %{private: %{phoenix_format: format}} = Acceptor.call(conn, [])

      assert ["json"] == format
    end
  end
end
