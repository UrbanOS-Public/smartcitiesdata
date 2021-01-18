defmodule DiscoveryApiWeb.MultipleDataControllerTest do
  use ExUnit.Case
  # use DiscoveryApi.DataCase

  use DiscoveryApiWeb.Test.AuthConnCase.IntegrationCase
  alias DiscoveryApi.Test.Helper

  setup_all do
    Helper.sample_model(%{
      systemName: "test__table"
    })
      |> Helper.save_model
  end

  describe "POST /query" do
    test "something", %{authorized_conn: conn} do
      _ = conn
          |> put_req_header("content-type", "text/plain")
          |> post("/api/v1/query", "SELECT * FROM test__table")
          |> response(200)
    end
  end
end
