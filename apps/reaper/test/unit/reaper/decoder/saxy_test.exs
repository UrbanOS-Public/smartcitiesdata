defmodule SaxyTest do
  use ExUnit.Case, async: true

  alias XMLStream.SaxHandler
  alias XMLStream.SaxHandler.State

  test "emits station data records in 'simple form'" do
    tag_path = ["stationData", "ns1:getPublicStationsResponse", "soapenv:Body", "soapenv:Envelope"]

    {:ok, _output} =
      "ChargePoint.xml"
      |> File.stream!([], 40_000)
      |> Saxy.parse_stream(SaxHandler, State.new(tag_path: tag_path, emitter: make_test_emitter()), expand_entity: :skip)

    assert_received {:emit, {"stationData", [], [{"stationID", [], ["1:41613"]} | _]}}
    assert_received {:emit, {"stationData", [], [{"stationID", [], ["1:111"]} | _]}}
  end

  test "emits row data records in 'simple form' from bigxml" do
    tag_path = ["response", "row", "row"] |> Enum.reverse()

    {:ok, _output} =
      "big.xml"
      |> File.stream!([], 40_000)
      |> Saxy.parse_stream(SaxHandler, State.new(tag_path: tag_path, emitter: make_test_emitter()), expand_entity: :skip)

    refute_received {:emit, {"row", _, [{"row", _, _} | _]}}
    assert_received {:emit, {"row", _, _}}
    assert_received {:emit, {"row", _, _}}
    assert_received {:emit, {"row", _, _}}
  end

  defp make_test_emitter do
    # Returns a closure with the test process PID
    fn msg -> send(self(), {:emit, msg}) end
  end
end
