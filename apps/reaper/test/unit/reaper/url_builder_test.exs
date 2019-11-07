defmodule Reaper.UrlBuilderTest do
  use ExUnit.Case
  use Placebo
  import Checkov
  alias Reaper.UrlBuilder

  setup do
    allow Reaper.Collections.Extractions.get_last_fetched_timestamp!(any()), return: nil

    :ok
  end

  data_test "builds #{result}" do
    assert result == UrlBuilder.build(dataset)

    where([
      [:dataset, :result],
      [
        SmartCity.TestDataGenerator.create_dataset(
          id: "",
          technical: %{
            sourceUrl: "https://my-url.com",
            sourceQueryParams: %{start_date: "19700101", end_date: "19700102"}
          }
        ),
        "https://my-url.com?end_date=19700102&start_date=19700101"
      ],
      [
        SmartCity.TestDataGenerator.create_dataset(
          id: "",
          technical: %{
            sourceUrl: "https://my-url.com",
            sourceQueryParams: %{
              start_date: "<%= Date.to_iso8601(~D[1970-01-01], :basic) %>",
              end_date: "<%= Date.to_iso8601(~D[1970-01-02], :basic) %>"
            }
          }
        ),
        "https://my-url.com?end_date=19700102&start_date=19700101"
      ],
      [
        SmartCity.TestDataGenerator.create_dataset(
          id: "",
          technical: %{
            sourceUrl: "https://my-url.com/date/<%= Date.to_iso8601(~D[1941-12-07], :basic) %>/stuff"
          }
        ),
        "https://my-url.com/date/19411207/stuff"
      ],
      [
        SmartCity.TestDataGenerator.create_dataset(
          id: "",
          technical: %{
            sourceUrl:
              "https://my-url.com/date/<%= Date.to_iso8601(~D[1941-12-07], :basic) %>/stuff/<%= Date.to_iso8601(~D[1999-12-31], :basic) %>/other",
            sourceQueryParams: %{something: "value"}
          }
        ),
        "https://my-url.com/date/19411207/stuff/19991231/other?something=value"
      ],
      [
        SmartCity.TestDataGenerator.create_dataset(
          id: "",
          technical: %{
            sourceUrl: "https://my-url.com",
            sourceQueryParams: %{}
          }
        ),
        "https://my-url.com"
      ],
      [
        SmartCity.TestDataGenerator.create_dataset(
          id: "",
          technical: %{
            sourceUrl: "https://my-url.com",
            sourceQueryParams: %{
              start_date:
                "<%= Date.to_iso8601(last_success_time || DateTime.from_unix!(0) |> DateTime.to_date(), :basic) %>",
              end_date: "<%= Date.to_iso8601(~D[1970-01-02], :basic) %>"
            }
          }
        ),
        "https://my-url.com?end_date=19700102&start_date=19700101"
      ],
      [
        SmartCity.TestDataGenerator.create_dataset(
          id: "",
          technical: %{
            sourceUrl: "s3://bucket-name/key/within/subdirectory.ext",
            sourceQueryParams: %{
              start_date: "foo",
              end_date: "bar"
            }
          }
        ),
        "s3://bucket-name/key/within/subdirectory.ext"
      ]
    ])
  end
end
