defmodule Andi.InputSchemas.FormToolsTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.FormTools
  alias Andi.Services.OrgStore

  describe "adjust_source_query_params_for_url/1" do
    test "given a url it sets the query params to match what is in it" do
      current_form_data = %{
        "technical" => %{
          "sourceUrl" => "https://source.url.example.com?look=at&me=i&have=params"
        }
      }

      updated_form_data = FormTools.adjust_source_query_params_for_url(current_form_data)

      assert %{
               "technical" => %{
                 "sourceQueryParams" => %{
                   "0" => %{"key" => "look", "value" => "at"},
                   "1" => %{"key" => "me", "value" => "i"},
                   "2" => %{"key" => "have", "value" => "params"}
                 }
               }
             } = updated_form_data
    end

    test "given form data with non-empty query params it replaces the query params to match what is in the url" do
      current_form_data = %{
        "technical" => %{
          "sourceUrl" => "https://source.url.example.com?look=at&me=i&have=params",
          "sourceQueryParams" => %{
            "0" => %{"key" => "surprisingly", "value" => "here"}
          }
        }
      }

      updated_form_data = FormTools.adjust_source_query_params_for_url(current_form_data)

      assert %{
               "technical" => %{
                 "sourceQueryParams" => %{
                   "0" => %{"key" => "look", "value" => "at"},
                   "1" => %{"key" => "me", "value" => "i"},
                   "2" => %{"key" => "have", "value" => "params"}
                 }
               }
             } = updated_form_data
    end

    test "given a url with partial URL encoding characters in it ignores them" do
      current_form_data = %{
        "technical" => %{
          "sourceUrl" => "https://source.url.example.com?invalid%=stuff",
          "sourceQueryParams" => %{
            "0" => %{"id" => "uuid-1", "key" => "still", "value" => "here"}
          }
        }
      }

      updated_form_data = FormTools.adjust_source_query_params_for_url(current_form_data)

      assert %{
               "technical" => %{
                 "sourceQueryParams" => %{
                   "0" => %{"key" => "still", "value" => "here"}
                 }
               }
             } = updated_form_data
    end

    test "given a url with URL encoding characters in it already it matches what's in the url" do
      current_form_data = %{
        "technical" => %{
          "sourceUrl" => "https://source.url.example.com?hello%20world=true&goodbye+scott=false"
        }
      }

      updated_form_data = FormTools.adjust_source_query_params_for_url(current_form_data)

      assert %{
               "technical" => %{
                 "sourceQueryParams" => %{
                   "0" => %{"key" => "hello world", "value" => "true"},
                   "1" => %{"key" => "goodbye scott", "value" => "false"}
                 }
               }
             } = updated_form_data
    end
  end

  describe "adjust_source_url_for_query_params/1" do
    test "given a url (with no params) and query params it sets url to match the query params" do
      current_form_data = %{
        "technical" => %{
          "sourceUrl" => "https://source.url.example.com",
          "sourceQueryParams" => %{
            "0" => %{"id" => "uuid-1", "key" => "look", "value" => "at"},
            "1" => %{"id" => "uuid-2", "key" => "me", "value" => "i"},
            "2" => %{"id" => "uuid-3", "key" => "have", "value" => "params"}
          }
        }
      }

      updated_form_data = FormTools.adjust_source_url_for_query_params(current_form_data)

      assert %{
               "technical" => %{
                 "sourceUrl" => "https://source.url.example.com?look=at&me=i&have=params",
                 "sourceQueryParams" => %{
                   "0" => %{"key" => "look", "value" => "at"},
                   "1" => %{"key" => "me", "value" => "i"},
                   "2" => %{"key" => "have", "value" => "params"}
                 }
               }
             } = updated_form_data
    end

    test "given a url and query params it sets url to match the query params" do
      current_form_data = %{
        "technical" => %{
          "sourceUrl" => "https://source.url.example.com?somehow=existing&params=yes",
          "sourceQueryParams" => %{
            "0" => %{"id" => "uuid-1", "key" => "look", "value" => "at"},
            "1" => %{"id" => "uuid-2", "key" => "me", "value" => "i"},
            "2" => %{"id" => "uuid-3", "key" => "have", "value" => "params"}
          }
        }
      }

      updated_form_data = FormTools.adjust_source_url_for_query_params(current_form_data)

      assert %{
               "technical" => %{
                 "sourceUrl" => "https://source.url.example.com?look=at&me=i&have=params",
                 "sourceQueryParams" => %{
                   "0" => %{"key" => "look", "value" => "at"},
                   "1" => %{"key" => "me", "value" => "i"},
                   "2" => %{"key" => "have", "value" => "params"}
                 }
               }
             } = updated_form_data
    end

    test "given a url (with no params) and empty query params it doesn't blow up" do
      current_form_data = %{
        "technical" => %{
          "sourceUrl" => "https://source.url.example.com",
          "sourceQueryParams" => %{}
        }
      }

      updated_form_data = FormTools.adjust_source_url_for_query_params(current_form_data)

      assert %{
               "technical" => %{
                 "sourceUrl" => "https://source.url.example.com",
                 "sourceQueryParams" => %{}
               }
             } = updated_form_data
    end

    test "given a url (with no params) and missing query params it doesn't blow up" do
      current_form_data = %{
        "technical" => %{
          "sourceUrl" => "https://source.url.example.com"
        }
      }

      updated_form_data = FormTools.adjust_source_url_for_query_params(current_form_data)

      assert %{
               "technical" => %{
                 "sourceUrl" => "https://source.url.example.com"
               }
             } = updated_form_data
    end
  end

  describe "adjust_data_name/1" do
    test "updating the data name also updates the system name" do
      current_form_data = %{
        "business" => %{
          "dataTitle" => "camio"
        },
        "technical" => %{
          "dataName" => "camio",
          "orgName" => "kevino",
          "systemName" => "kevino__italiano"
        }
      }

      new_form_data = FormTools.adjust_data_name(current_form_data)
      assert get_in(new_form_data, ["technical", "dataName"]) == "camio"
      assert get_in(new_form_data, ["technical", "systemName"]) == "kevino__camio"
    end
  end

  describe "adjust_org_name/1" do
    test "updating the orgTitle updates the orgName" do
      org = TDG.create_organization(%{orgTitle: "Another Org Title", orgName: "another_org_title", id: "95254592-d611-4bcb-9478-7fa248f4118d"})

      Placebo.allow(OrgStore.get(any()), return: {:ok, org})

      current_form_data = %{
        "business" => %{
          "orgTitle" => "95254592-d611-4bcb-9478-7fa248f4118d"
        },
        "technical" => %{
          "orgName" => "something_not_related",
          "orgId" => "95254592-d611-4bcb-9478-493583495843"
        }
      }

      new_form_data = FormTools.adjust_org_name(current_form_data)

      assert %{"business" => %{"orgTitle" => "Another Org Title"}, "technical" => %{"orgName" => "another_org_title", "orgId" => "95254592-d611-4bcb-9478-7fa248f4118d"}} == new_form_data
    end
  end
end
