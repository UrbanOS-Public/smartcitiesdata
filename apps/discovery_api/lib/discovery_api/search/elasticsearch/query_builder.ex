defmodule DiscoveryApi.Search.Elasticsearch.QueryBuilder do
  @moduledoc """
  Builds out the JSON body for an Elasticsearch query
  """
  require Logger

  # At maxiumum possible buckets (2_147_483_647) this can cause memory issues in ES
  @elasticsearch_max_buckets 4_000_000

  def build(search_opts \\ []) do
    IO.inspect(search_opts, label: "search options")

    query_json = %{
      "aggs" => %{
        "keywords" => %{"terms" => %{"field" => "facets.keywords", "size" => @elasticsearch_max_buckets}},
        "organization" => %{"terms" => %{"field" => "facets.orgTitle", "size" => @elasticsearch_max_buckets}}
      },
      "query" => %{
        "bool" => %{
          "must" => build_must(search_opts),
          "filter" => build_filter(search_opts)
        }
      },
      "from" => Keyword.get(search_opts, :offset, 0),
      "size" => Keyword.get(search_opts, :limit, 10),
      "sort" => [build_sort_map(search_opts)]
    }

    Logger.debug("#{__MODULE__}: ElasticSearch Query: #{inspect(query_json)}")
    query_json |> IO.inspect(label: "query_json")
  end

  defp build_must(search_opts) do
    query = Keyword.get(search_opts, :query, "")
    keywords = Keyword.get(search_opts, :keywords, [])
    org_title = Keyword.get(search_opts, :org_title, nil)
    api_accessible = Keyword.get(search_opts, :api_accessible, false)

    [
      match_terms(query),
      match_keywords(keywords),
      match_organization(org_title),
      api_accessible(api_accessible)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp match_terms(term) when term in ["", nil] do
    %{
      "match_all" => %{}
    }
  end

  defp match_terms(term) do
    %{
      "multi_match" => %{
        "fields" => ["title", "description", "organizationDetails.orgTitle", "keywords"],
        "fuzziness" => "AUTO",
        "prefix_length" => 2,
        "query" => term,
        "type" => "most_fields"
      }
    }
  end

  defp match_keywords([]), do: nil

  defp match_keywords(keywords) do
    %{
      "terms_set" => %{
        "facets.keywords" => %{
          "terms" => keywords,
          "minimum_should_match_script" => %{
            "source" => "return #{length(keywords)}"
          }
        }
      }
    }
  end

  defp api_accessible(false), do: nil

  defp api_accessible(true) do
    %{
      "terms" => %{
        "sourceType" => ["ingest", "stream"]
      }
    }
  end

  defp match_organization(nil), do: nil

  defp match_organization(org_title) do
    %{
      "term" => %{
        "facets.orgTitle" => org_title
      }
    }
  end

  defp build_filter(search_opts) do
    authorized_organization_ids = Keyword.get(search_opts, :authorized_organization_ids, [])
    authorized_access_group_ids = Keyword.get(search_opts, :authorized_access_groups, []) |> IO.inspect(label: "access groups")

    [
      %{
        "bool" => %{
          "should" => [
            %{
              "term" => %{
                "private" => false
              }
            },
            %{
              "bool" => %{
                "must" => [
                  %{
                    "term" => %{
                      "private" => true
                    }
                  },
                  %{
                    "bool" => %{
                      "should" => [
                        %{
                          "terms" => %{
                            # single
                            "organizationDetails.id" => authorized_organization_ids
                          }
                        },
                        # %{
                        #   "script" => %{
                        #     "script" => %{
                        #       "source" => "if(params['access_groups'].containsAny(doc['accessGroups'].values)){return true;}",
                        #       "params" => %{
                        #         "access_groups" => authorized_access_group_ids
                        #       }
                        #     }
                        #   }
                        # }
                        %{
                          "terms" => %{
                            "accessGroups" => authorized_access_group_ids
                          }
                        }
                        # %{
                        #   "terms_set" => %{
                        #     "accessGroups" => %{
                        #       "terms" => authorized_access_group_ids,
                        #       "minimum_should_match_script" => %{
                        #         "source" => "1"
                        #       }
                        #     }
                        #   }
                        # }
                      ]
                    }
                  }
                ]
              }
            }
          ]
        }
      }
    ]
  end

  defp build_sort_map(search_opts) do
    case Keyword.get(search_opts, :sort, "name_asc") do
      "name_asc" -> %{"titleKeyword" => %{"order" => "asc"}}
      "name_desc" -> %{"titleKeyword" => %{"order" => "desc"}}
      "last_mod" -> %{"sortDate" => %{"order" => "desc"}}
      "relevance" -> %{}
    end
  end
end
