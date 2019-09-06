defmodule DiscoveryApiWeb.MultipleMetadataViewTest do
  use DiscoveryApiWeb.ConnCase, async: true
  import Phoenix.View
  import Checkov
  alias DiscoveryApi.Data.Model

  test "renders search_dataset_summaries.json" do
    actual =
      render(
        DiscoveryApiWeb.MultipleMetadataView,
        "search_dataset_summaries.json",
        models: [
          %Model{
            :id => 1,
            :name => "name",
            :title => "title",
            :systemName => "foo__bar_baz",
            :keywords => ["cat"],
            :organization => "org",
            :organizationDetails => %{orgName: "org_name", orgTitle: "org", logoUrl: "org.png"},
            :modifiedDate => "today",
            :fileTypes => ["csv", "pdf"],
            :description => "best ever",
            :sourceUrl => "http://example.com",
            :sourceType => "remote",
            :private => false,
            :lastUpdatedDate => :date_placeholder
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
          :name => "name",
          :title => "title",
          :keywords => ["cat"],
          :systemName => "foo__bar_baz",
          :organization_title => "org",
          :organization_name => "org_name",
          :organization_image_url => "org.png",
          :modified => "today",
          :fileTypes => ["csv", "pdf"],
          :description => "best ever",
          :sourceUrl => "http://example.com",
          :sourceType => "remote",
          :lastUpdatedDate => :date_placeholder
        }
      ]
    }

    assert actual == expected
  end

  describe "sort" do
    data_test "correctly orders results by #{sort_by}" do
      models = create_models()

      actual =
        render(
          DiscoveryApiWeb.MultipleMetadataView,
          "search_dataset_summaries.json",
          %{
            models: models,
            facets: %{organization: [name: "org", count: 1], keywords: [name: "cat", count: 1]},
            sort: sort_by,
            offset: 0,
            limit: 1000
          }
        )
        |> Map.get("results")
        |> Enum.map(&Map.get(&1, :title))

      assert actual == expected

      where([
        [:sort_by, :expected],
        [
          "name_asc",
          [
            "a_remote_times",
            "b_remote_no_time",
            "c_stream_last_updated",
            "d_ingest_modified",
            "e_nill_dates",
            "f_ingest_modified",
            "g_ingest_modified",
            "h_ingest_date_no_time",
            "i_empty_dates"
          ]
        ],
        [
          "name_desc",
          [
            "i_empty_dates",
            "h_ingest_date_no_time",
            "g_ingest_modified",
            "f_ingest_modified",
            "e_nill_dates",
            "d_ingest_modified",
            "c_stream_last_updated",
            "b_remote_no_time",
            "a_remote_times"
          ]
        ],
        [
          "last_mod",
          [
            "d_ingest_modified",
            "c_stream_last_updated",
            "f_ingest_modified",
            "g_ingest_modified",
            "h_ingest_date_no_time",
            "i_empty_dates",
            "e_nill_dates",
            "b_remote_no_time",
            "a_remote_times"
          ]
        ]
      ])
    end
  end

  defp create_models() do
    [
      %{
        title: "a_remote_times",
        description: "remote with times are ignored",
        sourceType: "remote",
        lastUpdatedDate: "2019-07-27T19:20:22.141769Z",
        modifiedDate: "2019-07-29T19:20:22.141769Z"
      },
      %{
        title: "c_stream_last_updated",
        description: "stream uses last update time",
        sourceType: "stream",
        lastUpdatedDate: "2019-07-26T19:20:22.141769Z",
        modifiedDate: "2019-07-28T19:20:22.141769Z"
      },
      %{title: "b_remote_no_time", description: "remote without time", sourceType: "remote", lastUpdatedDate: nil, modifiedDate: nil},
      %{
        title: "d_ingest_modified",
        description: "ingest uses modified date",
        sourceType: "ingest",
        lastUpdatedDate: "2018-07-27T19:20:22.141769Z",
        modifiedDate: "2020-12-27T19:20:22.141769Z"
      },
      %{
        title: "e_nill_dates",
        description: "datasets without times are sorted last, but still before remotes",
        sourceType: "ingest",
        lastUpdatedDate: nil,
        modifiedDate: nil
      },
      %{
        title: "i_empty_dates",
        description: "datasets without times are sorted last, but still before remotes",
        sourceType: "ingest",
        lastUpdatedDate: "",
        modifiedDate: ""
      },
      %{
        title: "f_ingest_modified",
        description: "ingests can come before or after streaming, just depends on what date is most recent",
        sourceType: "ingest",
        lastUpdatedDate: "2020-12-27T19:20:22.141769Z",
        modifiedDate: "2019-06-27T19:20:22.141769Z"
      },
      %{
        title: "g_ingest_modified",
        description: "sort is by both date and time",
        sourceType: "ingest",
        lastUpdatedDate: "2019-12-27T19:20:22.141769Z",
        modifiedDate: "2019-06-27T19:10:22.141769Z"
      },
      %{
        title: "h_ingest_date_no_time",
        description: "no time means all 0s",
        sourceType: "ingest",
        lastUpdatedDate: "2019-12-27T00:00:00.000000Z",
        modifiedDate: "2019-06-27T00:00:00.000000Z"
      }
    ]
    |> Enum.map(&create_model/1)
  end

  defp create_model(%{
         title: title,
         description: description,
         lastUpdatedDate: lastUpdatedDate,
         modifiedDate: modifiedDate,
         sourceType: sourceType
       }) do
    %Model{
      :id => 1,
      :name => "name",
      :title => title,
      :systemName => "foo__bar_baz",
      :keywords => ["cat"],
      :organization => "org",
      :organizationDetails => %{orgName: "org_name", orgTitle: "org", logoUrl: "org.png"},
      :modifiedDate => modifiedDate,
      :fileTypes => ["csv", "pdf"],
      :description => "best ever",
      :sourceUrl => "http://example.com",
      :sourceType => sourceType,
      :private => false,
      :lastUpdatedDate => lastUpdatedDate
    }
  end
end
