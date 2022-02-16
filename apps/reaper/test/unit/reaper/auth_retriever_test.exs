defmodule AuthRetrieverTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG

  alias Reaper.Collections.Extractions
  alias Reaper.Cache.AuthCache

  @ingestion_id "123"
  @dataset_id "some-dataset"
  @auth_response Jason.encode!(%{"api_key" => "12343523423423"})

  setup do
    Cachex.start(AuthCache.cache_name())
    Cachex.clear(AuthCache.cache_name())

    :ok
  end

  describe "authorize/6" do
    test "retrieve response using auth headers and url" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      headers = %{
        "key1" => "value1",
        "key2" => "value2"
      }

      Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
        assert "value1" == Plug.Conn.get_req_header(conn, "key1") |> List.last()
        assert "value2" == Plug.Conn.get_req_header(conn, "key2") |> List.last()
        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      assert Reaper.AuthRetriever.authorize(@ingestion_id, url, "body", "encode-method", headers, 10_000) ==
               @auth_response
    end

    test "retrieve response when auth headers is a list" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      headers = [
        {:key1, "value1"},
        {:key2, "value2"}
      ]

      Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
        assert "value1" == Plug.Conn.get_req_header(conn, "key1") |> List.last()
        assert "value2" == Plug.Conn.get_req_header(conn, "key2") |> List.last()
        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      assert Reaper.AuthRetriever.authorize(@ingestion_id, url, "body", "encode-method", headers, 10_000) ==
               @auth_response
    end

    test "retrieve response using auth body and url" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      expected_body = %{
        secret_thing: "secret"
      }

      Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
        {:ok, actual_body, _} = Plug.Conn.read_body(conn)
        assert actual_body == URI.encode_query(expected_body)
        assert "application/x-www-form-urlencoded" == Plug.Conn.get_req_header(conn, "content-type") |> List.last()

        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      assert Reaper.AuthRetriever.authorize(
               @ingestion_id,
               url,
               URI.encode_query(expected_body),
               "encode-method",
               %{},
               10_000
             ) ==
               @auth_response
    end

    test "retrieve response with json encoded body" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      expected_body = %{secret_thing: "secret"}

      Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
        {:ok, actual_body, _} = Plug.Conn.read_body(conn)
        assert "application/json" == Plug.Conn.get_req_header(conn, "content-type") |> List.last()
        assert actual_body == Jason.encode!(expected_body)
        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      assert Reaper.AuthRetriever.authorize(@ingestion_id, url, Jason.encode!(expected_body), "json", %{}, 10_000) ==
               @auth_response
    end

    test "caches auth response body" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      Bypass.stub(bypass, "POST", "/auth", fn conn ->
        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      assert Reaper.AuthRetriever.authorize(@ingestion_id, url, "body", "encode-method", %{}, 10_000) == @auth_response

      Bypass.down(bypass)

      bypass = Bypass.open(port: bypass.port)

      Bypass.stub(bypass, "POST", "/auth", fn conn ->
        Plug.Conn.resp(conn, 401, "[]")
      end)

      assert Reaper.AuthRetriever.authorize(@ingestion_id, url, "body", "encode-method", %{}, 10_000) == @auth_response
    end

    test "caches response for specified ttl" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      Bypass.stub(bypass, "POST", "/auth", fn conn ->
        Plug.Conn.resp(conn, 200, @auth_response)
      end)

      assert Reaper.AuthRetriever.authorize(@ingestion_id, url, "body", "encode-method", %{}, 1) == @auth_response

      Bypass.down(bypass)

      bypass = Bypass.open(port: bypass.port)

      Bypass.stub(bypass, "POST", "/auth", fn conn ->
        Plug.Conn.resp(conn, 200, "other_auth_response")
      end)

      Process.sleep(2)

      assert Reaper.AuthRetriever.authorize(@ingestion_id, url, "body", "encode-method", %{}, 1) ==
               "other_auth_response"
    end

    test "raise and do not cache if bad status code" do
      bypass = Bypass.open()
      url = "http://localhost:#{bypass.port}/auth"

      Bypass.expect_once(bypass, "POST", "/auth", fn conn ->
        Plug.Conn.resp(conn, 400, @auth_response)
      end)

      assert_raise(RuntimeError, ~r/#{@ingestion_id}.*400/, fn ->
        Reaper.AuthRetriever.authorize(@ingestion_id, url, "body", "encode-method", %{}, 10_000)
      end)

      assert AuthCache.get(@ingestion_id) == nil
    end
  end
end
