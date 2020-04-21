defmodule EstuaryWeb.StreamingEventLiveViewTest do
  use ExUnit.Case
  use EstuaryWeb.ConnCase
  use Phoenix.ConnTest
  use Placebo

  import Phoenix.LiveViewTest

  import FlokiHelpers, only: [get_text: 2]

  alias Estuary.MessageHandler
  import SmartCity.TestHelper

  describe "GET events from /streaming-events" do
    @tag capture_log: true
    test "should return OK and all the events in html format to display", %{conn: conn} do
      event_1 = %{
            "author" => "Author-2020-04-21 23:29:20.171519Z",
            "create_ts" => 1_579_649_360,
            "data" => "Data-2020-04-21 23:29:20.171538Z",
            "type" => "Type-2020-04-21 23:29:20.171543Z"
          }
      event_2 = %{
            "author" => "Author-2020-04-21 23:25:52.522084Z",
            "create_ts" => 1_579_649_152,
            "data" => "Data-2020-04-21 23:25:52.522107Z",
            "type" => "Type-2020-04-21 23:25:52.522111Z"
          }
      messages = [%{
        value: Jason.encode!(event_1)
      },
      %{
        value: Jason.encode!(event_2)
      }]

      expected_events =
        "Author Create Timestamp Data Type Author-2020-04-21 23:29:20.171519Z1579649360Data-2020-04-21 23:29:20.171538ZType-2020-04-21 23:29:20.171543ZAuthor-2020-04-21 23:25:52.522084Z1579649152Data-2020-04-21 23:25:52.522107ZType-2020-04-21 23:25:52.522111Z"

      assert {:ok, view, html} = live(conn, "/streaming-events")

      MessageHandler.handle_messages(messages)

      eventually(
        fn ->
          html = render(view)
          actual_events = get_text(html, ".events-index__table")
          assert 2 == find_elements(html, ".events-table__tr") |> Enum.count()
          assert 4 == find_elements(html, ".events-table__th") |> Enum.count()
          assert 12 == find_elements(html, ".events-table__cell") |> Enum.count()
          assert expected_events == actual_events
        end,
        2000,
        10
      )
    end
  end

  defp find_elements(html, selector) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find(selector)
  end
end
