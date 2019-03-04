defmodule Reaper.UrlBuilderTest do
  use ExUnit.Case
  use Placebo
  import Checkov
  alias Reaper.UrlBuilder

  data_test "builds #{result}" do
    assert result == UrlBuilder.build(dataset)

    where([
      [:dataset, :result],
      [
        %Dataset{
          business: "",
          id: "",
          operational: %{
            sourceUrl: "https://my-url.com",
            queryParams: %{start_date: "19700101", end_date: "19700102"}
          }
        },
        "https://my-url.com?end_date=19700102&start_date=19700101"
      ],
      [
        %Dataset{
          business: "",
          id: "",
          operational: %{
            sourceUrl: "https://my-url.com",
            queryParams: %{
              start_date: "<%= Date.to_iso8601(~D[1970-01-01], :basic) %>",
              end_date: "<%= Date.to_iso8601(~D[1970-01-02], :basic) %>"
            }
          }
        },
        "https://my-url.com?end_date=19700102&start_date=19700101"
      ],
      [
        %Dataset{
          business: "",
          id: "",
          operational: %{
            sourceUrl: "https://my-url.com",
            queryParams: %{}
          }
        },
        "https://my-url.com"
      ],
      [
        %Dataset{
          business: "",
          id: "",
          operational: %{
            sourceUrl: "https://my-url.com",
            queryParams: %{
              start_date: "<%= Date.to_iso8601(last_success_time |> DateTime.to_date(), :basic) %>",
              end_date: "<%= Date.to_iso8601(~D[1970-01-02], :basic) %>"
            },
            lastSuccessTime: "2019-02-27T18:40:03.239976Z"
          }
        },
        "https://my-url.com?end_date=19700102&start_date=20190227"
      ],
      [
        %Dataset{
          business: "",
          id: "",
          operational: %{
            sourceUrl: "https://my-url.com",
            queryParams: %{
              start_date:
                "<%= Date.to_iso8601(last_success_time || DateTime.from_unix!(0) |> DateTime.to_date(), :basic) %>",
              end_date: "<%= Date.to_iso8601(~D[1970-01-02], :basic) %>"
            }
          }
        },
        "https://my-url.com?end_date=19700102&start_date=19700101"
      ]
    ])
  end
end
