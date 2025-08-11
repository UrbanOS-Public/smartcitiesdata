defmodule XMLStream.SaxHandlerTest do
  use ExUnit.Case, async: true

  alias XMLStream.SaxHandler

  @test_file_path "test/support/test_data/"
  defp test_file_path(filename) do
    @test_file_path <> filename
  end

  test "emits station data records in 'simple form'" do
    tag_path = "soapenv:Envelope/soapenv:Body/ns1:getPublicStationsResponse/stationData"

    {:ok, _output} =
      "ChargePoint.xml"
      |> test_file_path()
      |> SaxHandler.start_stream(tag_path, make_test_emitter())

    assert_received {:emit, {"stationData", [], [{:characters, "\n        "}, {"stationID", [], [characters: "1:41613"]} | _]}}
    assert_received {:emit, {"stationData", [], [{:characters, "\n        "}, {"stationID", [], [characters: "1:111"]} | _]}}
  end

  test "emits row data records in 'simple form' from a file with repeated tag names" do
    tag_path = "response/row/row"

    {:ok, _output} =
      "repeat.xml"
      |> test_file_path()
      |> SaxHandler.start_stream(tag_path, make_test_emitter())

    refute_received {:emit, {"row", _, [{"row", _, _} | _]}}
    assert_received {:emit, {"row", _, _}}
    assert_received {:emit, {"row", _, _}}
    assert_received {:emit, {"row", _, _}}
  end

  test "handles escaping special characters" do
    tag_path = "response/row/row"

    {:ok, _output} =
      "repeat.xml"
      |> test_file_path()
      |> SaxHandler.start_stream(tag_path, make_test_emitter())

    all_rows = get_all_emits() |> Enum.map(&Saxy.encode!/1)

    Enum.each(all_rows, fn row ->
      assert String.contains?(row, "&amp;")
    end)
  end

  defp make_test_emitter do
    # Returns a closure with the test process PID
    fn msg -> send(self(), {:emit, msg}) end
  end

  defp get_all_emits(msgs \\ []) do
    receive do
      {:emit, msg} -> get_all_emits([msg | msgs])
    after
      0 -> msgs
    end
  end
end
