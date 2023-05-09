defmodule AndiWeb.Helpers.FormToolsTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias AndiWeb.Helpers.FormTools
  alias Andi.Services.OrgStore

  describe "adjust_source_query_params_for_url/1" do
    test "given a url it sets the query params to match what is in it" do
      current_form_data = %{
        "sourceUrl" => "https://source.url.example.com?look=at&me=i&have=params"
      }

      updated_form_data = FormTools.adjust_source_query_params_for_url(current_form_data)

      assert %{
               "sourceQueryParams" => [
                 %{"key" => "look", "value" => "at"},
                 %{"key" => "me", "value" => "i"},
                 %{"key" => "have", "value" => "params"}
               ]
             } = updated_form_data
    end

    test "given form data with non-empty query params it replaces the query params to match what is in the url" do
      current_form_data = %{
        "sourceUrl" => "https://source.url.example.com?look=at&me=i&have=params",
        "sourceQueryParams" => %{
          "0" => %{"key" => "surprisingly", "value" => "here"}
        }
      }

      updated_form_data = FormTools.adjust_source_query_params_for_url(current_form_data)

      assert %{
               "sourceQueryParams" => [
                 %{"key" => "look", "value" => "at"},
                 %{"key" => "me", "value" => "i"},
                 %{"key" => "have", "value" => "params"}
               ]
             } = updated_form_data
    end

    test "given a url with partial URL encoding characters in it ignores them" do
      current_form_data = %{
        "sourceUrl" => "https://source.url.example.com?invalid%=stuff",
        "sourceQueryParams" => %{
          "0" => %{"id" => "uuid-1", "key" => "still", "value" => "here"}
        }
      }

      updated_form_data = FormTools.adjust_source_query_params_for_url(current_form_data)

      assert %{
               "sourceQueryParams" => %{
                 "0" => %{"key" => "still", "value" => "here"}
               }
             } = updated_form_data
    end

    test "given a url with URL encoding characters in it already it matches what's in the url" do
      current_form_data = %{
        "sourceUrl" => "https://source.url.example.com?hello%20world=true&goodbye+scott=false"
      }

      updated_form_data = FormTools.adjust_source_query_params_for_url(current_form_data)

      assert %{
               "sourceQueryParams" => [%{"key" => "hello world", "value" => "true"}, %{"key" => "goodbye scott", "value" => "false"}]
             } = updated_form_data
    end
  end

  describe "adjust_source_url_for_query_params/1" do
    test "given a url (with no params) and query params it sets url to match the query params" do
      current_form_data = %{
        "sourceUrl" => "https://source.url.example.com",
        "sourceQueryParams" => %{
          "0" => %{"id" => "uuid-1", "key" => "look", "value" => "at"},
          "1" => %{"id" => "uuid-2", "key" => "me", "value" => "i"},
          "2" => %{"id" => "uuid-3", "key" => "have", "value" => "params"}
        }
      }

      updated_form_data = FormTools.adjust_source_url_for_query_params(current_form_data)

      assert %{
               "sourceUrl" => "https://source.url.example.com?look=at&me=i&have=params",
               "sourceQueryParams" => %{
                 "0" => %{"key" => "look", "value" => "at"},
                 "1" => %{"key" => "me", "value" => "i"},
                 "2" => %{"key" => "have", "value" => "params"}
               }
             } = updated_form_data
    end

    test "given a url and query params it sets url to match the query params" do
      current_form_data = %{
        "sourceUrl" => "https://source.url.example.com?somehow=existing&params=yes",
        "sourceQueryParams" => %{
          "0" => %{"id" => "uuid-1", "key" => "look", "value" => "at"},
          "1" => %{"id" => "uuid-2", "key" => "me", "value" => "i"},
          "2" => %{"id" => "uuid-3", "key" => "have", "value" => "params"}
        }
      }

      updated_form_data = FormTools.adjust_source_url_for_query_params(current_form_data)

      assert %{
               "sourceUrl" => "https://source.url.example.com?look=at&me=i&have=params",
               "sourceQueryParams" => %{
                 "0" => %{"key" => "look", "value" => "at"},
                 "1" => %{"key" => "me", "value" => "i"},
                 "2" => %{"key" => "have", "value" => "params"}
               }
             } = updated_form_data
    end

    test "given a url (with no params) and empty query params it doesn't blow up" do
      current_form_data = %{
        "sourceUrl" => "https://source.url.example.com",
        "sourceQueryParams" => %{}
      }

      updated_form_data = FormTools.adjust_source_url_for_query_params(current_form_data)

      assert %{
               "sourceUrl" => "https://source.url.example.com",
               "sourceQueryParams" => %{}
             } = updated_form_data
    end

    test "given a url (with no params) and missing query params it doesn't blow up" do
      current_form_data = %{
        "sourceUrl" => "https://source.url.example.com"
      }

      updated_form_data = FormTools.adjust_source_url_for_query_params(current_form_data)

      assert %{
               "sourceUrl" => "https://source.url.example.com"
             } = updated_form_data
    end
  end

  describe "adjust_data_name/1" do
    test "updating the data name also updates the system name" do
      current_form_data = %{
        "dataTitle" => "camio",
        "dataName" => "camio",
        "orgName" => "kevino",
        "systemName" => "kevino__italiano"
      }

      new_form_data = FormTools.adjust_data_name(current_form_data)
      assert new_form_data["dataName"] == "camio"
      assert new_form_data["systemName"] == "kevino__camio"
    end
  end

  describe "adjust_org_name/1" do
    test "updating the orgId updates the orgName" do
      org = TDG.create_organization(%{orgTitle: "Existing Org Title", orgName: "existing_org_name", id: "existing_org_id"})

      Placebo.allow(OrgStore.get(any()), return: {:ok, org})

      current_form_data = %{
        "orgTitle" => "Another Org Title",
        "dataName" => "another_data_title",
        "orgName" => "something_not_related",
        "orgId" => "existing_org_id"
      }

      new_form_data = FormTools.adjust_org_name(current_form_data)

      assert %{
               "orgTitle" => "Existing Org Title",
               "dataName" => "another_data_title",
               "orgName" => "existing_org_name",
               "orgId" => "existing_org_id",
               "systemName" => "existing_org_name__another_data_title"
             } == new_form_data
    end
  end
end
