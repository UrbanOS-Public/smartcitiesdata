defmodule AuthRetrieverTest do
  use ExUnit.Case
  use Placebo

  @instance Reaper.Application.instance()
  @dataset_id "123"
  @auth_response Jason.encode!(%{"api_key" => "12343523423423"})

  describe "retrieve/1" do
    test "retrieve response using auth headers and url" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      headers = %{
        "key1" => "value1",
        "key2" => "value2"
      }

      reaper_config =
        FixtureHelper.new_reaper_config(%{
          dataset_id: @dataset_id,
          authUrl: url,
          authHeaders: headers
        })

      Bypass.stub(bypass, "POST", "/auth", fn conn ->
        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      allow Brook.get!(@instance, :reaper_config, @dataset_id), return: reaper_config
      assert Reaper.AuthRetriever.retrieve(@dataset_id) == Jason.decode!(@auth_response)
    end

    test "retrieve response using auth body and url" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      expected_body = %{
        secret_thing: "secret"
      }

      reaper_config =
        FixtureHelper.new_reaper_config(%{
          dataset_id: @dataset_id,
          authUrl: url,
          authHeaders: %{},
          authBody: expected_body
        })

      Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
        {:ok, actual_body, _} = Plug.Conn.read_body(conn)
        assert actual_body == URI.encode_query(expected_body)
        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      allow Brook.get!(@instance, :reaper_config, @dataset_id), return: reaper_config
      assert Reaper.AuthRetriever.retrieve(@dataset_id) == Jason.decode!(@auth_response)
    end

    test "retrieve response with no body or headers" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      reaper_config =
        FixtureHelper.new_reaper_config(%{
          dataset_id: @dataset_id,
          authUrl: url
        })

      Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
        {:ok, actual_body, _} = Plug.Conn.read_body(conn)
        assert actual_body == ""
        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      allow Brook.get!(@instance, :reaper_config, @dataset_id), return: reaper_config
      assert Reaper.AuthRetriever.retrieve(@dataset_id) == Jason.decode!(@auth_response)
    end

    test "evaluate auth headers" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      headers = %{
        "key1" => "value1",
        "key2" => "<%= Date.to_iso8601(~D[1970-01-01], :basic) %>"
      }

      reaper_config =
        FixtureHelper.new_reaper_config(%{
          dataset_id: @dataset_id,
          authUrl: url,
          authHeaders: headers
        })

      Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
        assert "value1" == Plug.Conn.get_req_header(conn, "key1") |> List.last()
        assert "19700101" == Plug.Conn.get_req_header(conn, "key2") |> List.last()
        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      allow Brook.get!(@instance, :reaper_config, @dataset_id), return: reaper_config

      Reaper.AuthRetriever.retrieve(@dataset_id)
    end
  end

  test "evaluate auth body" do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}/auth"

    body = %{
      "key1" => "value1",
      "key2" => "<%= Date.to_iso8601(~D[1970-01-01], :basic) %>"
    }

    evaluated_body = %{"key2" => "19700101", "key1" => "value1"} |> URI.encode_query()

    reaper_config =
      FixtureHelper.new_reaper_config(%{
        dataset_id: @dataset_id,
        authUrl: url,
        authBody: body
      })

    Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
      {:ok, actual_body, _} = Plug.Conn.read_body(conn)
      assert actual_body == evaluated_body
      Plug.Conn.resp(conn, 200, @auth_response)
    end)

    allow Brook.get!(@instance, :reaper_config, @dataset_id), return: reaper_config

    Reaper.AuthRetriever.retrieve(@dataset_id)
  end
end
