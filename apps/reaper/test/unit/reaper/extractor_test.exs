defmodule Reaper.ExtractorTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.Extractor

  describe(".decode") do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "when given GTFS protobuf body and a gtfs format it returns it as a list of entities", %{
      bypass: bypass
    } do
      Bypass.stub(bypass, "GET", "/1.1/statuses/update.csv", fn conn ->
        conn
        |> Phoenix.Controller.redirect(
          external: "http://localhost:#{bypass.port}/1.1/statuses/update2.csv"
        )
      end)

      Bypass.stub(bypass, "GET", "/1.1/statuses/update2.csv", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          ~s<one,two\n1,2\n>
        )
      end)

      actual =
        Extractor.extract("http://localhost:#{bypass.port}/1.1/statuses/update.csv")
        |> IO.inspect(label: "extractor_test.exs:35")

      assert actual == ~s<one,two\n1,2\n>
    end
  end
end
