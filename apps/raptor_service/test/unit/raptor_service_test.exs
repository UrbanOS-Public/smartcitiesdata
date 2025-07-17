defmodule RaptorServiceTest do
  use ExUnit.Case, async: true
  import Mox

  Mox.defmock(HTTPoison.BaseMock, for: HTTPoison.Base)

  setup do
    Application.put_env(:raptor_service, :http_client, HTTPoison.BaseMock)
    :ok
  end

  describe "is_authorized/2" do
    test "returns true if authorized in Raptor" do
      expect(HTTPoison.BaseMock, :get, fn _url ->
        {:ok, %HTTPoison.Response{status_code: 200, body: "{\"is_authorized\":true}"}}
      end)

      assert RaptorService.is_authorized("raptor_url", "ap1K3y", "system__name")
    end

    test "returns false if unauthorized in Raptor" do
      expect(HTTPoison.BaseMock, :get, fn _url ->
        {:ok, %HTTPoison.Response{status_code: 200, body: "{\"is_authorized\":false}"}}
      end)

      assert not RaptorService.is_authorized("raptor_url", "ap1K3y", "system__name")
    end
  end

  describe "is_authorized_by_user_id/2" do
    test "returns true if authorized in Raptor" do
      expect(HTTPoison.BaseMock, :get, fn _url ->
        {:ok, %HTTPoison.Response{status_code: 200, body: "{\"is_authorized\":true}"}}
      end)

      assert RaptorService.is_authorized_by_user_id("raptor_url", "user_id", "system__name")
    end

    test "returns false if unauthorized in Raptor" do
      expect(HTTPoison.BaseMock, :get, fn _url ->
        {:ok, %HTTPoison.Response{status_code: 200, body: "{\"is_authorized\":false}"}}
      end)

      assert not RaptorService.is_authorized_by_user_id("raptor_url", "user_id", "system__name")
    end
  end

  describe "regenerate_api_key_for_user/2" do
    test "regenerates api key for a user" do
      expect(HTTPoison.BaseMock, :patch, fn _url, _body ->
        {:ok, %HTTPoison.Response{body: "{\"apiKey\": \"testApiKey\"}", status_code: 200}}
      end)

      assert RaptorService.regenerate_api_key_for_user("raptor_url", "user_id") ==
               {:ok, %{"apiKey" => "testApiKey"}}
    end

    test "returns error when status code is >= 400" do
      expect(HTTPoison.BaseMock, :patch, fn _url, _body ->
        {:ok, %HTTPoison.Response{body: "errorBody", status_code: 400}}
      end)

      assert RaptorService.regenerate_api_key_for_user("raptor_url", "user_id") ==
               {:error, "errorBody"}
    end
  end

  describe "list_groups_by_user/2" do
    test "returns a list of authorized access groups in Raptor" do
      expect(HTTPoison.BaseMock, :get, fn _url ->
        {:ok,
         %HTTPoison.Response{
           body: "{\"access_groups\":[\"group1\", \"group2\"], \"organizations\": []}"
         }}
      end)

      assert RaptorService.list_groups_by_user("raptor_url", "user_id") ==
               %{access_groups: ["group1", "group2"], organizations: []}
    end

    test "returns an empty list if there are no access groups authorized for the given user" do
      expect(HTTPoison.BaseMock, :get, fn _url ->
        {:ok, %HTTPoison.Response{body: "{\"access_groups\":[], \"organizations\": []}"}}
      end)

      assert RaptorService.list_groups_by_user("raptor_url", "user_id") ==
               %{access_groups: [], organizations: []}
    end
  end

  describe "list_access_groups_by_dataset/2" do
    test "returns a list of authorized access groups in Raptor" do
      expect(HTTPoison.BaseMock, :get, fn _url ->
        {:ok, %HTTPoison.Response{body: "{\"access_groups\":[\"group1\", \"group2\"]}"}}
      end)

      assert RaptorService.list_access_groups_by_dataset("raptor_url", "dataset_id") ==
               %{access_groups: ["group1", "group2"]}
    end

    test "returns an empty list if there are no access groups authorized for the given dataset" do
      expect(HTTPoison.BaseMock, :get, fn _url ->
        {:ok, %HTTPoison.Response{body: "{\"access_groups\":[]}"}}
      end)

      assert RaptorService.list_access_groups_by_dataset("raptor_url", "dataset_id") ==
               %{access_groups: []}
    end
  end

  describe "list_groups_by_api_key/2" do
    test "returns a list of authorized access groups in Raptor" do
      expect(HTTPoison.BaseMock, :get, fn _url ->
        {:ok,
         %HTTPoison.Response{
           body: "{\"access_groups\":[\"group1\", \"group2\"], \"organizations\": []}"
         }}
      end)

      assert RaptorService.list_groups_by_api_key("raptor_url", "apiKey") ==
               %{access_groups: ["group1", "group2"], organizations: []}
    end

    test "returns an empty list if there are no access groups authorized for the given dataset" do
      expect(HTTPoison.BaseMock, :get, fn _url ->
        {:ok, %HTTPoison.Response{body: "{\"access_groups\":[], \"organizations\":[]}"}}
      end)

      assert RaptorService.list_groups_by_api_key("raptor_url", "apiKey") ==
               %{access_groups: [], organizations: []}
    end
  end

  describe "get_user_id_from_api_key/2" do
    test "returns 500 Internal Server Error when raptor returns unexpected error" do
      expect(HTTPoison.BaseMock, :get, fn _url ->
        {:error, %HTTPoison.Error{reason: :econnrefused}}
      end)

      assert RaptorService.get_user_id_from_api_key("raptor_url", "invalidApiKey") ==
               {:error, "Internal Server Error", 500}
    end

    test "returns given error when raptor returns 401" do
      errorMessage = "errorMessage"

      expect(HTTPoison.BaseMock, :get, fn _url ->
        {:ok, %HTTPoison.Response{body: "{\"message\":\"#{errorMessage}\"}", status_code: 401}}
      end)

      assert RaptorService.get_user_id_from_api_key("raptor_url", "invalidApiKey") ==
               {:error, errorMessage, 401}
    end

    test "returns true when raptor returns is_valid_api_key true" do
      raptor_url = "raptor_url"
      api_key = "validApiKey"
      user_id = "validUserId"

      expect(HTTPoison.BaseMock, :get, fn url ->
        assert url == "#{raptor_url}/getUserIdFromApiKey?api_key=#{api_key}"
        {:ok, %HTTPoison.Response{body: "{\"user_id\":\"#{user_id}\"}", status_code: 200}}
      end)

      assert RaptorService.get_user_id_from_api_key(raptor_url, api_key) == {:ok, user_id}
    end
  end

  describe "check_auth0_role/2" do
    test "returns 500 Internal Server Error when raptor returns unexpected error" do
      expect(HTTPoison.BaseMock, :get, fn _url ->
        {:error, %HTTPoison.Error{reason: :econnrefused}}
      end)

      assert RaptorService.check_auth0_role("raptor_url", "invalidApiKey", "notARole") ==
               {:error, "Internal Server Error", 500}
    end

    test "returns given error when raptor returns 401" do
      errorMessage = "errorMessage"

      expect(HTTPoison.BaseMock, :get, fn _url ->
        {:ok, %HTTPoison.Response{body: "{\"message\":\"#{errorMessage}\"}", status_code: 401}}
      end)

      assert RaptorService.check_auth0_role("raptor_url", "invalidApiKey", "notARole") ==
               {:error, errorMessage, 401}
    end

    test "returns true in has_role when raptor finds matching role" do
      raptor_url = "raptor_url"
      api_key = "validApiKey"
      role = "validRole"

      expect(HTTPoison.BaseMock, :get, fn url ->
        assert url == "#{raptor_url}/checkRole?api_key=#{api_key}&role=#{role}"
        {:ok, %HTTPoison.Response{body: "{\"has_role\":true}", status_code: 200}}
      end)

      assert RaptorService.check_auth0_role(raptor_url, api_key, role) == {:ok, true}
    end
  end
end