defmodule Andi.Services.UrlTestTest do
  use ExUnit.Case
  use Placebo

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
      response = Andi.Services.UrlTest.test("http://bobisthegreatest123.co.llc")

      assert %{status: "Domain not found"} = response
    end
  end
end
