defmodule EstuaryWeb.API.EventControllerTest do
  use EstuaryWeb.ConnCase
  use Placebo
  alias Estuary.Services.EventRetrievalService

  describe "GET events from /api/v1/events" do
    @tag capture_log: true
    test "returns a 200", %{conn: conn} do
      expected_events = [
        %{
          "author" => "Author-2020-01-21 23:29:20.171519Z",
          "create_ts" => 1_579_649_360,
          "data" => "Data-2020-01-21 23:29:20.171538Z",
          "type" => "Type-2020-01-21 23:29:20.171543Z"
        },
        %{
          "author" => "Author-2020-01-21 23:25:52.522084Z",
          "create_ts" => 1_579_649_152,
          "data" => "Data-2020-01-21 23:25:52.522107Z",
          "type" => "Type-2020-01-21 23:25:52.522111Z"
        }
      ]

      allow(EventRetrievalService.get_all(), return: expected_events)

      conn = get(conn, "/api/v1/events")

      actual_events =
        conn
        |> json_response(200)

      assert expected_events == actual_events
    end
  end
end
