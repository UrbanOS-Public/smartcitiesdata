defmodule DiscoveryApiWeb.ApiKeyControllerTest do
  use DiscoveryApiWeb.ConnCase
  import Mox
  alias DiscoveryApiWeb.Test.AuthTestHelper

  setup :verify_on_exit!
  setup :set_mox_from_context

  @apiKey %{
    apiKey: "1234"
  }

  describe "api key controller" do
    test "regenerates api key", %{conn: conn} do
      expected = %{
        "apiKey" => @apiKey.apiKey
      }

      # Use the existing auth infrastructure instead of trying to mock Guardian.Plug
      conn = AuthTestHelper.assign_test_user(conn, %{subject_id: @apiKey.apiKey})
      
      # Use RaptorServiceMock for the service call
      expect(RaptorServiceMock, :regenerate_api_key_for_user, fn _, _ -> 
        {:ok, %{"apiKey" => @apiKey.apiKey}} 
      end)

      actual =
        conn
        |> patch("/api/v1/regenerateApiKey")
        |> json_response(200)

      assert expected == actual
    end

    test "returns 500 if raptor service returns error", %{conn: conn} do
      # Use the existing auth infrastructure with nil subject_id
      conn = AuthTestHelper.assign_test_user(conn, %{subject_id: nil})
      
      # Use RaptorServiceMock for the service call
      expect(RaptorServiceMock, :regenerate_api_key_for_user, fn _, _ -> 
        {:error, "Does not exist"} 
      end)
      
      actual = conn |> patch("/api/v1/regenerateApiKey") |> json_response(500)

      assert %{"message" => "Internal Server Error"} = actual
    end
  end
end
