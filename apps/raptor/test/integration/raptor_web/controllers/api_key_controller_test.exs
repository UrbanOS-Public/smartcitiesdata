defmodule Raptor.ApiKeyControllerTest do
  use ExUnit.Case
  use Placebo

  use Tesla
  use Properties, otp_app: :raptor

  import SmartCity.TestHelper, only: [eventually: 1]
  import SmartCity.Event
  alias SmartCity.TestDataGenerator, as: TDG
  alias Raptor.Services.DatasetStore
  alias Raptor.Schemas.Dataset
  alias Raptor.Services.UserOrgAssocStore
  alias Raptor.Schemas.UserOrgAssoc
  alias Raptor.Services.Auth0Management
  alias Raptor.Services.UserAccessGroupRelationStore
  alias Raptor.Schemas.UserAccessGroupRelation
  alias Raptor.Services.DatasetAccessGroupRelationStore
  alias Raptor.Schemas.DatasetAccessGroupRelation

  @instance_name Raptor.instance_name()

  getter(:kafka_broker, generic: true)

  describe "regenerateApiKey" do
    test "returns apiKey for user when auth0 patch is successful" do
      userId = "auth0|001122"

      allow(Auth0Management.patch_api_key(userId, any()),
        return: {:ok, %{body: "{\"app_metadata\": {\"apiKey\": \"testApiKey\"}}"}}
      )

      {:ok, response} =
        HTTPoison.patch("http://localhost:4002/api/regenerateApiKey?user_id=#{userId}", "")

      {:ok, body} = Jason.decode(response.body)
      assert body == %{"apiKey" => "testApiKey"}
    end

    test "returns Internal Server Error when auth0 call fails" do
      userId = "auth0|001122"

      allow(Auth0Management.patch_api_key(userId, any()),
        return: {:error, "error"}
      )

      {:ok, response} =
        HTTPoison.patch("http://localhost:4002/api/regenerateApiKey?user_id=#{userId}", "")

      {:ok, body} = Jason.decode(response.body)

      assert response.status_code == 500
      assert body["message"] == "Internal Server Error"
    end

    test "returns error when user_id is not given" do
      userId = "auth0|001122"

      allow(Auth0Management.patch_api_key(userId, any()),
        return: {:ok, %{body: "{\"apiKey\": \"testApiKey\"}"}}
      )

      {:ok, response} = HTTPoison.patch("http://localhost:4002/api/regenerateApiKey", "")
      {:ok, body} = Jason.decode(response.body)

      assert response.status_code == 400
      assert body["message"] == "user_id is a required parameter"
    end
  end
end
