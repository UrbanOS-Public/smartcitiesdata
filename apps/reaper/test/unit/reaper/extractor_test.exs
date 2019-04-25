defmodule Reaper.ExtractorTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.Extractor

  describe "extract" do
    setup do
      bypass = Bypass.open()
      filename = inspect(self())

      on_exit(fn ->
        if File.exists?(filename) do
          File.rm(filename)
        end
      end)

      {:ok, bypass: bypass}
    end

    test "downloads csvs to file on local filesystem", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/1.2/data.csv", fn conn ->
        Plug.Conn.resp(conn, 200, ~s|one,two,three\n1,2,3\n|)
      end)

      {:file, filename} = Extractor.extract("http://localhost:#{bypass.port}/1.2/data.csv", "csv")

      assert ~s|one,two,three\n1,2,3\n| == File.read!(filename)
    end

    test "When the extractor encounters a redirect it follows it to the source", %{
      bypass: bypass
    } do
      Bypass.stub(bypass, "GET", "/1.1/statuses/update.json", fn conn ->
        conn
        |> Phoenix.Controller.redirect(external: "http://localhost:#{bypass.port}/1.1/statuses/update2.json")
      end)

      Bypass.stub(bypass, "GET", "/1.1/statuses/update2.json", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          ~s<one,two\n1,2\n>
        )
      end)

      actual = Extractor.extract("http://localhost:#{bypass.port}/1.1/statuses/update.json", "json")

      assert actual == ~s<one,two\n1,2\n>
    end
  end

  describe "failure to extract" do
    test "RuntimeError are bubbled up instead of masked as a match error" do
      assert_raise RuntimeError, fn ->
        Extractor.extract("http://localhost:100/1.1/statuses/update.json", "json")
      end
    end
  end
end
