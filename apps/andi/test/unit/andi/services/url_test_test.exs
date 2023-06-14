defmodule Andi.Services.UrlTestTest do
  use ExUnit.Case

  describe "test/1" do
    test "returns status code from tested url" do
      bypass = Bypass.open()

      Bypass.stub(bypass, "HEAD", "/test", fn conn ->
        Plug.Conn.resp(conn, 200, "yes")
      end)

      response = Andi.Services.UrlTest.test("http://localhost:#{bypass.port()}/test")

      assert %{status: 200} = response
    end

    test "returns time to execute for tested url in milliseconds" do
      bypass = Bypass.open()

      Bypass.stub(bypass, "HEAD", "/test", fn conn ->
        Plug.Conn.resp(conn, 200, "yes")
      end)

      response = Andi.Services.UrlTest.test("http://localhost:#{bypass.port()}/test")

      assert %{time: time} = response
      assert is_float(time)
    end

    test "returns custom status message for non-existant domains" do
      response = Andi.Services.UrlTest.test("invalid-domain")

      assert %{status: "Domain not found"} = response
    end

    test "sends HEAD request with query params when provided" do
      query_params = [{"a", "b"}, {"c", ""}, {"d", "e"}]
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "HEAD", "/test", fn conn ->
        actual = Plug.Conn.fetch_query_params(conn) |> Map.get(:query_params)

        assert length(query_params) == actual |> Map.keys() |> length()

        Enum.each(query_params, fn {key, value} ->
          assert actual[key] == value
        end)

        Plug.Conn.resp(conn, 200, "yes")
      end)

      Andi.Services.UrlTest.test("http://localhost:#{bypass.port()}/test", query_params: query_params)
    end

    test "sends HEAD request with headers when provided" do
      headers = [{"a", "b"}, {"c", ""}, {"d", "e"}]
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "HEAD", "/test", fn conn ->
        Enum.each(headers, fn header ->
          assert header in conn.req_headers
        end)

        Plug.Conn.resp(conn, 200, "yes")
      end)

      Andi.Services.UrlTest.test("http://localhost:#{bypass.port()}/test", headers: headers)
    end
  end
end
