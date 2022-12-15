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

  describe "getUserIdFromApiKey" do
    test "returns Internal Server Error when auth0 call fails" do
      allow(Auth0Management.get_users_by_api_key(any()),
        return: {:error, "error"}
      )

      {:ok, response} =
        HTTPoison.get("http://localhost:4002/api/getUserIdFromApiKey?api_key=invalidApiKey")

      {:ok, body} = Jason.decode(response.body)

      assert response.status_code == 500
      assert body["message"] == "Internal Server Error"
    end

    test "returns false when apiKey does not match any users" do
      allow(Auth0Management.get_users_by_api_key(any()),
        return: {:ok, []}
      )

      {:ok, response} =
        HTTPoison.get("http://localhost:4002/api/getUserIdFromApiKey?api_key=invalidApiKey")

      body = Jason.decode!(response.body)

      assert body == %{"message" => "No user found with given API Key."}
      assert response.status_code == 401
    end

    test "returns true when apiKey has a single matching user" do
      user_id = "123"
      api_key = "validApiKey"

      allow(Auth0Management.get_users_by_api_key(any()),
        return: {:ok, [%{"email_verified" => true, "user_id" => "#{user_id}"}]}
      )

      {:ok, response} =
        HTTPoison.get("http://localhost:4002/api/getUserIdFromApiKey?api_key=#{api_key}")

      assert response == {:ok, %{body: "{\"user_id\": \"#{user_id}\"}"}, status_code: 200}
    end
  end
end
