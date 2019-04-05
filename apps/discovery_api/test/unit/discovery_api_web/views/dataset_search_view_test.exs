defmodule DiscoveryApiWeb.DatasetSearchViewTest do
  use DiscoveryApiWeb.ConnCase, async: true
  import Phoenix.View

  test "renders search_dataset_summaries.json" do
    actual =
      render(
        DiscoveryApiWeb.DatasetSearchView,
        "search_dataset_summaries.json",
        datasets: [
          %DiscoveryApi.Data.Dataset{
            :id => 1,
            :title => "title",
            :systemName => "foo__bar_baz",
            :keywords => ["cat"],
            :organization => "org",
            :modified => "today",
            :fileTypes => ["csv", "pdf"],
            :description => "best ever",
            :sourceUrl => "http://example.com",
            :sourceType => "remote",
            :private => false
          }
        ],
        facets: %{organization: [name: "org", count: 1], keywords: [name: "cat", count: 1]},
        sort: "name_asc",
        offset: 0,
        limit: 1000
      )

    expected = %{
      "metadata" => %{
        "facets" => %{organization: [name: "org", count: 1], keywords: [name: "cat", count: 1]},
        "limit" => 1000,
        "offset" => 0,
        "totalDatasets" => 1
      },
      "results" => [
        %{
          :id => 1,
          :title => "title",
          :keywords => ["cat"],
          :systemName => "foo__bar_baz",
          :organization => "org",
          :modified => "today",
          :fileTypes => ["csv", "pdf"],
          :description => "best ever",
          :sourceUrl => "http://example.com",
          :sourceType => "remote",
          :private => false
        }
      ]
    }

    assert actual == expected
  end
end
