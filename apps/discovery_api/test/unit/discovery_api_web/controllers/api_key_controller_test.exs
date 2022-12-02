defmodule DiscoveryApiWeb.ApiKeyControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Schemas.Organizations
  alias DiscoveryApi.Schemas.Organizations.Organization

  @apiKey %{
    apiKey: "1234"
  }

  describe "api key controller" do
    test "regenerates api key", %{conn: conn} do
      expected = %{
        "apiKey" => @apiKey.apiKey
      }

      expect(Guardian.Plug.current_resource(any()), return: %{subject_id: @apiKey.apiKey})
      expect(RaptorService.regenerate_api_key_for_user(any(), any()), return: {:ok, %{"apiKey" => @apiKey.apiKey}})

      actual =
        conn
        |> IO.inspect(label: "into_get")
        |> patch("/api/v1/regenerateApiKey")
        |> IO.inspect(label: "into_json_response")
        |> json_response(200)

      assert expected == actual
    end

    test "returns 500 if raptor service returns error", %{conn: conn} do
      expect(Guardian.Plug.current_resource(any()), return: %{subject_id: nil})
      expect(RaptorService.regenerate_api_key_for_user(any(), any()), return: {:error, "Does not exist"})
      actual = conn |> patch("/api/v1/regenerateApiKey") |> json_response(500)

      assert %{"message" => "Internal Server Error"} = actual
    end
  end
end
