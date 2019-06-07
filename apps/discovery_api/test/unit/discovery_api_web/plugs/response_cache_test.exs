defmodule DiscoveryApiWeb.Plugs.ResponseCacheTest do
  use ExUnit.Case
  use Plug.Test
  alias DiscoveryApiWeb.Plugs.ResponseCache

  setup do
    Cachex.clear(DiscoveryApiWeb.Plugs.ResponseCache)

    :ok
  end

  describe "response cache plug" do
    test "non default searches return an unmodified conn" do
      for_params = [%{"offset" => "0", "limit" => "5", "query" => "search"}]
      conn = conn(:get, "/a/path", %{"offset" => "0", "limit" => "5", "query" => "nemesis"})

      actual = ResponseCache.call(conn, %{for_params: for_params})

      assert actual == conn
    end

    test "searches matching for_params will registrer before send hook that caches the response" do
      for_params = [%{"offset" => "0", "limit" => "5", "query" => ""}]
      conn = conn(:get, "/a/path", %{"offset" => "0", "limit" => "5", "query" => ""})

      actual = ResponseCache.call(conn, %{for_params: for_params})

      assert {:ok, 0} == Cachex.count(DiscoveryApiWeb.Plugs.ResponseCache)

      [function] = actual.before_send

      conn
      |> put_resp_header("nemesis", "austin")
      |> send_resp(200, "Howdy")
      |> function.()

      {:ok, cache_entry} = Cachex.get(ResponseCache, {conn.request_path, conn.params})

      assert {"nemesis", "austin"} in cache_entry.resp_headers
      assert "Howdy" == cache_entry.resp_body
    end

    test "searches matching for_params with entry already in the cache will return the cache immediately" do
      for_params = [%{"offset" => "0", "limit" => "10", "query" => ""}]
      conn = conn(:get, "/a/path", %{"offset" => "0", "limit" => "10", "query" => ""})

      resp_headers = [{"test_header", "value_header"}]
      resp_body = "Some HTML"
      Cachex.put(ResponseCache, {conn.request_path, conn.params}, %{resp_headers: resp_headers, resp_body: resp_body})
      actual = ResponseCache.call(conn, %{for_params: for_params})

      assert actual.resp_body == "Some HTML"
      assert {"test_header", "value_header"} in actual.resp_headers
      assert actual.halted == true
    end

    test "clears cache when invalidate is called" do
      Cachex.put(ResponseCache, {"/path", %{"one" => "1"}}, %{resp_headers: [{"one", "two"}], resp_body: "Body"})

      ResponseCache.invalidate()

      assert {:ok, 0} == Cachex.count(ResponseCache)
    end
  end
end
