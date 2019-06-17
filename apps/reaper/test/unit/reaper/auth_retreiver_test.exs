defmodule AuthRetrieverTest do
  use ExUnit.Case
  use Placebo

  describe "retrieve/1" do
    test "retrieve response using auth headers and url" do
      bypass = Bypass.open()

      dataset_id = "123"
      url = "http://localhost:#{bypass.port}/auth"

      headers = %{
        "key1" => "value1",
        "key2" => "value2"
      }

      reaper_config =
        FixtureHelper.new_reaper_config(%{
          dataset_id: dataset_id,
          authUrl: url,
          authHeaders: headers
        })

      expected = %{"api_key" => "12343523423423"}
      auth_response = Jason.encode!(expected)

      Bypass.stub(bypass, "POST", "/auth", fn conn ->
        Plug.Conn.resp(conn, 200, auth_response)
      end)

      allow(Reaper.Persistence.get(dataset_id), return: reaper_config)
      assert Reaper.AuthRetriever.retrieve(dataset_id) == expected
    end

    test "evaluate auth headers" do
      dataset_id = "123"
      url = "www.example.com"

      headers = %{
        "key1" => "value1",
        "key2" => "<%= Date.to_iso8601(~D[1970-01-01], :basic) %>"
      }

      evaluated_headers = %{"key2" => "19700101", "key1" => "value1"}

      reaper_config =
        FixtureHelper.new_reaper_config(%{
          dataset_id: dataset_id,
          authUrl: url,
          authHeaders: headers
        })

      response = %{body: Jason.encode!(%{"api_key" => "12343523423423"})}

      allow(Reaper.Persistence.get(dataset_id), return: reaper_config)
      allow(HTTPoison.post!(any(), any(), any()), return: response)

      Reaper.AuthRetriever.retrieve(dataset_id)

      assert_called(HTTPoison.post!(url, "", evaluated_headers))
    end
  end
end
