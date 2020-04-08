defmodule Andi.InputSchemas.FormToolsTest do
  use ExUnit.Case

  alias Andi.InputSchemas.FormTools

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
end
