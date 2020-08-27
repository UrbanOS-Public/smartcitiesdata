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
      ]
    ])
  end

  data_test "builds #{result} for extract steps" do
    assert result == UrlBuilder.decode_http_extract_step(step)

    where([
      [:step, :result],
      [
        # Simple Url
        %{
          type: "http",
          context: %{
            url: "https://extract_steps.com",
            queryParams: %{},
            assigns: %{}
          }
        },
        "https://extract_steps.com"
      ],
      [
        # Url with simple query params
        %{
          type: "http",
          context: %{
            url: "https://my-url.com",
            queryParams: %{start_date: "19700101", end_date: "19700102"},
            assigns: %{}
          }
        },
        "https://my-url.com?end_date=19700102&start_date=19700101"
      ],
      [
        #Url with path parameters from assigns block
        %{
          type: "http",
          context: %{
            url: "https://my-url.com/{{date}}/key/{{key}}",
            queryParams: %{},
            assigns: %{
              date: "19700101",
              key: "SECRET"
            }
          }
        },
        "https://my-url.com/19700101/key/SECRET"
      ],
      [
        #Url with query parameters from assigns block
        %{
          type: "http",
          context: %{
            url: "https://my-url.com",
            queryParams: %{
              token: "{{key}}"
            },
            assigns: %{
              key: "SECRET"
            }
          }
        },
        "https://my-url.com?token=SECRET"
      ]
    ])
  end
end
