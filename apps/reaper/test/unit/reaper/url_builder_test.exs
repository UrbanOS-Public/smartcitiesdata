defmodule Reaper.UrlBuilderTest do
  use ExUnit.Case
  import Mox
  import Checkov
  alias Reaper.UrlBuilder

  setup :verify_on_exit!

  setup do
    # Note: This mock would need to be implemented if Reaper.Collections.Extractions is actually used
    # For now, removing it as it's not clear this module exists in the current codebase
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

  test "safe evaluate xml body with bindings replaces bindings successfully" do
    body =
      "<soap12:Envelope>\n  <soap12:Body>\n    <{{date}} xmlns=\"{{key}}\">\n    </{{date}}>\n  </soap12:Body>\n</soap12:Envelope>"

    bindings = %{
      date: "19700101",
      key: "SECRET"
    }

    expected =
      "<soap12:Envelope>\n  <soap12:Body>\n    <19700101 xmlns=\"SECRET\">\n    </19700101>\n  </soap12:Body>\n</soap12:Envelope>"

    assert UrlBuilder.safe_evaluate_body(body, bindings) == expected
  end

  test "safe evaluate json body with bindings replaces bindings successfully" do
    body = "{\"{{date}}\": \"{{key}}\"}"

    bindings = %{
      date: "19700101",
      key: "SECRET"
    }

    expected = "{\"19700101\": \"SECRET\"}"

    assert UrlBuilder.safe_evaluate_body(body, bindings) == expected
  end

  test "safe evaluate body without bindings returns existing body with no changes" do
    body = "<soap12:Envelope>\n  <soap12:Body>\n    <Test>\n    </Test>\n  </soap12:Body>\n</soap12:Envelope>"

    bindings = %{}

    expected = "<soap12:Envelope>\n  <soap12:Body>\n    <Test>\n    </Test>\n  </soap12:Body>\n</soap12:Envelope>"

    assert UrlBuilder.safe_evaluate_body(body, bindings) == expected
  end
end
