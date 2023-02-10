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
    test "returns userID from redis cache when found" do
      user_id = "987"
      api_key = "validApiKey"

      auth0_user_data = %Raptor.Schemas.Auth0UserData{
        user_id: user_id,
        app_metadata: %{apiKey: api_key},
        email_verified: true,
        blocked: false
      }

      Raptor.Services.Auth0UserDataStore.persist(auth0_user_data)

      # Do not allow Auth0 calls
      allow(Auth0Management.get_users_by_api_key(any()),
        return: {:error, "error"}
      )

      {:ok, response} =
        HTTPoison.get("http://localhost:4002/api/getUserIdFromApiKey?api_key=#{api_key}")

      body = Jason.decode!(response.body)

      assert body == %{"user_id" => "#{user_id}"}
      assert response.status_code == 200
    end

    test "returns userID from Auth0 when redis cache is empty" do
      user_id = "654"
      api_key = "nonCachedApiKey"

      Raptor.Services.Auth0UserDataStore.delete_by_api_key(api_key)
      allow(Raptor.Services.Auth0UserDataStore.get_user_by_api_key(api_key),
        return: []
      )

      allow(Tesla.get(any(), any()),
        return: {:ok, %{body: "[{\"app_metadata\": {\"apiKey\": \"#{api_key}\"}, \"email_verified\": true, \"user_id\": \"#{user_id}\", \"blocked\": false}]"}}
      )

      allow(Tesla.post(any(), any(), any()),
        return: {:ok, %{body: "{\"access_token\": \"foo\"}"}}
      )

      {:ok, response} =
        HTTPoison.get("http://localhost:4002/api/getUserIdFromApiKey?api_key=#{api_key}")

      body = Jason.decode!(response.body)

      assert body == %{"user_id" => "#{user_id}"}
      assert response.status_code == 200
    end

    test "caches user data to redis after Auth0 API call" do
      user_id = "654"
      api_key = "nonCachedApiKey"

      Raptor.Services.Auth0UserDataStore.delete_by_api_key(api_key)
      assert Raptor.Services.Auth0UserDataStore.get_user_by_api_key(api_key) == []

      allow(Tesla.get(any(), any()),
        return: {:ok, %{body: "[{\"app_metadata\": {\"apiKey\": \"#{api_key}\"}, \"email_verified\": true, \"user_id\": \"#{user_id}\", \"blocked\": false}]"}}
      )
      allow(Tesla.post(any(), any(), any()),
        return: {:ok, %{body: "{\"access_token\": \"foo\"}"}}
      )

      {:ok, response} =
        HTTPoison.get("http://localhost:4002/api/getUserIdFromApiKey?api_key=#{api_key}")

      expected_redis_data = [
      %Raptor.Schemas.Auth0UserData{
        app_metadata: %{apiKey: api_key},
        user_id: user_id,
        email_verified: true,
        blocked: false
      }
      ]
      assert Raptor.Services.Auth0UserDataStore.get_user_by_api_key(api_key) == expected_redis_data

      body = Jason.decode!(response.body)

      assert body == %{"user_id" => "#{user_id}"}
      assert response.status_code == 200
    end

    test "returns Internal Server Error when auth0 call fails" do
      allow(Auth0Management.get_users_by_api_key(any()),
        return: {:error, "error"}
      )
      allow(Raptor.Services.Auth0UserDataStore.get_user_by_api_key(any()),
        return: []
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
  end
end
