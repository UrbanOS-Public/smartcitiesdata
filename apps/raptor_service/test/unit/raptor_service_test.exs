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

  describe "list_access_groups_by_user/2" do
    test "returns a list of authorized access groups in Raptor" do
      allow(HTTPoison.get(any()),
        return: {:ok, %{body: "{\"access_groups\":[\"group1\", \"group2\"]}"}}
      )

      assert RaptorService.list_access_groups_by_user("raptor_url", "user_id") == ["group1", "group2"]
    end

    test "returns an empty list if there are no access groups authorized for the given user" do
      allow(HTTPoison.get(any()),
        return: {:ok, %{body: "{\"access_groups\":[]}"}}
      )

      assert not RaptorService.list_access_groups_by_user("raptor_url", "user_id") == []
    end
  end

  describe "list_access_groups_by_dataset/2" do
    test "returns a list of authorized access groups in Raptor" do
      allow(HTTPoison.get(any()),
        return: {:ok, %{body: "{\"access_groups\":[\"group1\", \"group2\"]}"}}
      )

      assert RaptorService.list_access_groups_by_dataset("raptor_url", "dataset_id") == ["group1", "group2"]
    end

    test "returns an empty list if there are no access groups authorized for the given dataset" do
      allow(HTTPoison.get(any()),
        return: {:ok, %{body: "{\"access_groups\":[]}"}}
      )

      assert not RaptorService.list_access_groups_by_dataset("raptor_url", "dataset_id") == []
    end
  end
end
