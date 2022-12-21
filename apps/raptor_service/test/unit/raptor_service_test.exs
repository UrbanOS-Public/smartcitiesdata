defmodule RaptorServiceTest do
  use ExUnit.Case
  use Placebo

  describe "is_authorized/2" do
    test "returns true if authorized in Raptor" do
      allow(HTTPoison.get(any()),
        return: {:ok, %{body: "{\"is_authorized\":true}"}}
      )

      assert RaptorService.is_authorized("raptor_url", "ap1K3y", "system__name")
    end

    test "returns false if unauthorized in Raptor" do
      allow(HTTPoison.get(any()),
        return: {:ok, %{body: "{\"is_authorized\":false}"}}
      )

      assert not RaptorService.is_authorized("raptor_url", "ap1K3y", "system__name")
    end
  end

  describe "is_authorized_by_user_id/2" do
    test "returns true if authorized in Raptor" do
      allow(HTTPoison.get(any()),
        return: {:ok, %{body: "{\"is_authorized\":true}"}}
      )

      assert RaptorService.is_authorized("raptor_url", "user_id", "system__name")
    end

    test "returns false if unauthorized in Raptor" do
      allow(HTTPoison.get(any()),
        return: {:ok, %{body: "{\"is_authorized\":false}"}}
      )

      assert not RaptorService.is_authorized("raptor_url", "user_id", "system__name")
    end
  end

  describe "regenerate_api_key_for_user/2" do
    allow(HTTPoison.patch(any(), any()),
        return: {:ok, %{body: "{\"apiKey\": \"testApiKey\"}", status_code: 200}}
      )

    assert RaptorService.regenerate_api_key_for_user("raptor_url", "user_id") == {:ok, %{"apiKey" => "testApiKey"}}
  end

  describe "regenerate_api_key_for_user/2 returns error when status code is >= 400" do
    allow(HTTPoison.patch(any(), any()),
        return: {:ok, %{body: "errorBody", status_code: 400}}
      )

    assert RaptorService.regenerate_api_key_for_user("raptor_url", "user_id") == {:error, "errorBody"}
  end

  describe "list_access_groups_by_user/2" do
    test "returns a list of authorized access groups in Raptor" do
      allow(HTTPoison.get(any()),
        return: {:ok, %{body: "{\"access_groups\":[\"group1\", \"group2\"], \"organizations\": []}"}}
      )

      assert RaptorService.list_groups_by_user("raptor_url", "user_id") == %{access_groups: ["group1", "group2"], organizations: []}
    end

    test "returns an empty list if there are no access groups authorized for the given user" do
      allow(HTTPoison.get(any()),
        return: {:ok, %{body: "{\"access_groups\":[], \"organizations\": []}"}}
      )

      assert RaptorService.list_groups_by_user("raptor_url", "user_id") == %{access_groups: [], organizations: []}
    end
  end

  describe "list_access_groups_by_dataset/2" do
    test "returns a list of authorized access groups in Raptor" do
      allow(HTTPoison.get(any()),
        return: {:ok, %{body: "{\"access_groups\":[\"group1\", \"group2\"]}"}}
      )

      assert RaptorService.list_access_groups_by_dataset("raptor_url", "dataset_id") == %{access_groups: ["group1", "group2"]}
    end

    test "returns an empty list if there are no access groups authorized for the given dataset" do
      allow(HTTPoison.get(any()),
        return: {:ok, %{body: "{\"access_groups\":[]}"}}
      )

      assert RaptorService.list_access_groups_by_dataset("raptor_url", "dataset_id") == %{access_groups: []}
    end
  end

  describe "list_access_groups_by_api_key/2" do
    test "returns a list of authorized access groups in Raptor" do
      allow(HTTPoison.get(any()),
        return: {:ok, %{body: "{\"access_groups\":[\"group1\", \"group2\"], \"organizations\": []}"}}
      )

      assert RaptorService.list_groups_by_api_key("raptor_url", "apiKey") == %{access_groups: ["group1", "group2"], organizations: []}
    end

    test "returns an empty list if there are no access groups authorized for the given dataset" do
      allow(HTTPoison.get(any()),
        return: {:ok, %{body: "{\"access_groups\":[], \"organizations\":[]}"}}
      )

      assert RaptorService.list_groups_by_api_key("raptor_url", "apiKey") == %{access_groups: [], organizations: []}
    end
  end

  describe "get_user_id_from_api_key/2" do
    test "returns 500 Internal Server Error when raptor returns unexpected error" do
      allow(HTTPoison.get(any()),
          return: {:error, %{body: "errorBody", status_code: 500}}
        )

      assert RaptorService.get_user_id_from_api_key("raptor_url", "invalidApiKey") == {:error, "Internal Server Error", 500}
    end

    test "returns given error when raptor returns 401" do
      errorMessage = "errorMessage"

      allow(HTTPoison.get(any()),
          return: {:ok, %{body: "{\"message\":\"#{errorMessage}\"}", status_code: 401}}
        )

      assert RaptorService.get_user_id_from_api_key("raptor_url", "invalidApiKey") == {:error, errorMessage, 401}
    end

    test "returns true when raptor returns is_valid_api_key true" do
      raptor_url = "raptor_url"
      api_key = "validApiKey"
      user_id = "validUserId"

      allow(HTTPoison.get("#{raptor_url}/getUserIdFromApiKey?api_key=#{api_key}"),
          return: {:ok, %{body: "{\"user_id\":\"#{user_id}\"}", status_code: 200}}
        )

      assert RaptorService.get_user_id_from_api_key(raptor_url, api_key) == {:ok, user_id}
    end
  end
end
