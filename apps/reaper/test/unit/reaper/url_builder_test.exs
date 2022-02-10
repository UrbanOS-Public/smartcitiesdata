defmodule Reaper.UrlBuilderTest do
  use ExUnit.Case
  use Placebo
  import Checkov
  alias Reaper.UrlBuilder

  setup do
    allow Reaper.Collections.Extractions.get_last_fetched_timestamp!(any()), return: nil

    :ok
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
            queryParams: %{}
          },
          assigns: %{}
        },
        "https://extract_steps.com"
      ],
      [
        # Url with simple query params
        %{
          type: "http",
          context: %{
            url: "https://my-url.com",
            queryParams: %{start_date: "19700101", end_date: "19700102"}
          },
          assigns: %{}
        },
        "https://my-url.com?end_date=19700102&start_date=19700101"
      ],
      [
        # Url with path parameters from assigns block
        %{
          type: "http",
          context: %{
            url: "https://my-url.com/{{date}}/key/{{key}}",
            queryParams: %{}
          },
          assigns: %{
            date: "19700101",
            key: "SECRET"
          }
        },
        "https://my-url.com/19700101/key/SECRET"
      ],
      [
        # Url with query parameters from assigns block
        %{
          type: "http",
          context: %{
            url: "https://my-url.com",
            queryParams: %{
              token: "{{key}}"
            }
          },
          assigns: %{
            key: "SECRET"
          }
        },
        "https://my-url.com?token=SECRET"
      ]
    ])
  end
end
