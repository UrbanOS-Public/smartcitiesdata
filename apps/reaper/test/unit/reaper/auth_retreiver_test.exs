defmodule AuthRetrieverTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG

  alias Reaper.Collections.Extractions
  alias Reaper.Cache.AuthCache

  @dataset_id "123"
  @auth_response Jason.encode!(%{"api_key" => "12343523423423"})

  setup do
    Cachex.start(AuthCache.cache_name())
    Cachex.clear(AuthCache.cache_name())

    :ok
  end

  describe "retrieve/1" do
    test "retrieve response using auth headers and url" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      headers = %{
        "key1" => "value1",
        "key2" => "value2"
      }

      dataset = TDG.create_dataset(%{id: @dataset_id, technical: %{authUrl: url, authHeaders: headers}})

      Bypass.stub(bypass, "POST", "/auth", fn conn ->
        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      allow Extractions.get_dataset!(@dataset_id), return: dataset
      assert Reaper.AuthRetriever.retrieve(@dataset_id) == @auth_response
    end

    test "retrieve response using auth body and url" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      expected_body = %{
        secret_thing: "secret"
      }

      dataset =
        TDG.create_dataset(%{id: @dataset_id, technical: %{authUrl: url, authHeaders: %{}, authBody: expected_body}})

      Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
        {:ok, actual_body, _} = Plug.Conn.read_body(conn)
        assert actual_body == URI.encode_query(expected_body)
        assert "application/x-www-form-urlencoded" == Plug.Conn.get_req_header(conn, "content-type") |> List.last()

        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      allow Extractions.get_dataset!(@dataset_id), return: dataset
      assert Reaper.AuthRetriever.retrieve(@dataset_id) == @auth_response
    end

    test "retrieve response with no body or headers" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      dataset = TDG.create_dataset(%{id: @dataset_id, technical: %{authUrl: url}})

      Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
        {:ok, actual_body, _} = Plug.Conn.read_body(conn)
        assert actual_body == ""
        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      allow Extractions.get_dataset!(@dataset_id), return: dataset
      assert Reaper.AuthRetriever.retrieve(@dataset_id) == @auth_response
    end

    test "evaluate auth headers" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      headers = %{
        "key1" => "value1",
        "key2" => "<%= Date.to_iso8601(~D[1970-01-01], :basic) %>"
      }

      dataset = TDG.create_dataset(%{id: @dataset_id, technical: %{authUrl: url, authHeaders: headers}})

      Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
        assert "value1" == Plug.Conn.get_req_header(conn, "key1") |> List.last()
        assert "19700101" == Plug.Conn.get_req_header(conn, "key2") |> List.last()
        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      allow Extractions.get_dataset!(@dataset_id), return: dataset

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

    dataset = TDG.create_dataset(%{id: @dataset_id, technical: %{authUrl: url, authBody: body}})

    Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
      {:ok, actual_body, _} = Plug.Conn.read_body(conn)
      assert actual_body == evaluated_body
      Plug.Conn.resp(conn, 200, @auth_response)
    end)

    allow Extractions.get_dataset!(@dataset_id), return: dataset

    Reaper.AuthRetriever.retrieve(@dataset_id)
  end

  test "caches auth response body" do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}/auth"

    dataset = TDG.create_dataset(%{id: @dataset_id, technical: %{authUrl: url}})

    allow Extractions.get_dataset!(@dataset_id), return: dataset

    Bypass.stub(bypass, "POST", "/auth", fn conn ->
      Plug.Conn.resp(conn, 200, @auth_response)
    end)

    assert Reaper.AuthRetriever.retrieve(@dataset_id) == @auth_response

    Bypass.down(bypass)

    bypass = Bypass.open(port: bypass.port)

    Bypass.stub(bypass, "POST", "/auth", fn conn ->
      Plug.Conn.resp(conn, 401, "[]")
    end)

    assert Reaper.AuthRetriever.retrieve(@dataset_id) == @auth_response
  end

  test "caches response for specified ttl" do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}/auth"

    dataset = TDG.create_dataset(%{id: @dataset_id, technical: %{authUrl: url}})

    allow Extractions.get_dataset!(@dataset_id), return: dataset

    Bypass.stub(bypass, "POST", "/auth", fn conn ->
      Plug.Conn.resp(conn, 200, @auth_response)
    end)

    assert Reaper.AuthRetriever.retrieve(@dataset_id, 1) == @auth_response

    Bypass.down(bypass)

    bypass = Bypass.open(port: bypass.port)

    Bypass.stub(bypass, "POST", "/auth", fn conn ->
      Plug.Conn.resp(conn, 200, "other_auth_response")
    end)

    Process.sleep(2)

    assert Reaper.AuthRetriever.retrieve(@dataset_id, 1) == "other_auth_response"
  end

  test "caches auth response body based on dataset" do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}/auth"
    different_url = "http://localhost:#{bypass.port}/authx"

    dataset = TDG.create_dataset(%{id: @dataset_id, technical: %{authUrl: url}})

    different_dataset = TDG.create_dataset(%{id: @dataset_id, technical: %{authUrl: different_url}})

    allow Extractions.get_dataset!(@dataset_id), seq: [dataset, different_dataset]

    Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
      Plug.Conn.resp(conn, 200, @auth_response)
    end)

    Bypass.expect_once(bypass, "POST", "/authx", fn conn ->
      Plug.Conn.resp(conn, 200, "other_auth_response")
    end)

    assert Reaper.AuthRetriever.retrieve(@dataset_id) == @auth_response

    assert Reaper.AuthRetriever.retrieve(@dataset_id) == "other_auth_response"
  end

  test "raise and do not cache if bad status code" do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}/auth"

    dataset = TDG.create_dataset(%{id: @dataset_id, technical: %{authUrl: url}})

    Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
      Plug.Conn.resp(conn, 400, @auth_response)
    end)

    allow Extractions.get_dataset!(@dataset_id), return: dataset

    assert_raise(RuntimeError, ~r/#{@dataset_id}.*400/, fn -> Reaper.AuthRetriever.retrieve(@dataset_id) end)
    assert AuthCache.get(@dataset_id) == nil
  end
end
