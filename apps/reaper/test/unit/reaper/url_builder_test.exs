defmodule Reaper.UrlBuilderTest do
  use ExUnit.Case
  use Placebo
  import Checkov
  alias Reaper.UrlBuilder

  data_test "builds #{result} with url #{url} and query parameters #{inspect(query_params)}" do
    assert result == UrlBuilder.build(url, query_params)

    where([
      [:url, :query_params, :result],
      [
        "https://my-url.com",
        %{start_date: "19700101", end_date: "19700102"},
        "https://my-url.com?end_date=19700102&start_date=19700101"
      ],
      [
        "https://my-url.com",
        %{
          start_date: "<%= Date.to_iso8601(~D[1970-01-01], :basic)  %>",
          end_date: "<%= Date.to_iso8601(~D[1970-01-02], :basic)  %>"
        },
        "https://my-url.com?end_date=19700102&start_date=19700101"
      ],
      ["https://my-url.com", nil, "https://my-url.com"]
    ])
  end
end
