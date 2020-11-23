defmodule EstuaryWeb.StreamingEventLiveViewTest do
  use ExUnit.Case
  use EstuaryWeb.ConnCase
  use Placebo

  import Phoenix.LiveViewTest

  import FlokiHelpers, only: [get_text: 2]

  alias Estuary.MessageHandler

  @url_path "/streaming-events"
  @event_1 %{
    "author" => "Author-2020-04-21 23:29:20.171519Z",
    "create_ts" => 1_579_649_360,
    "data" => "Data-2020-04-21 23:29:20.171538Z",
    "type" => "Type-2020-04-21 23:29:20.171543Z"
  }

  @event_2 %{
    "author" => "Author-2020-04-21 23:25:52.522084Z",
    "create_ts" => 1_579_649_152,
    "data" => "Data-2020-04-21 23:25:52.522107Z",
    "type" => "Type-2020-04-21 23:25:52.522111Z"
  }

  describe "GET events from /streaming-events" do
    @tag capture_log: true
    test "should return OK and all the events in html format to display", %{conn: conn} do
      expected_event =
        "Author Create Timestamp Data Type Author-2020-04-21 23:29:20.171519Z1579649360Data-2020-04-21 23:29:20.171538ZType-2020-04-21 23:29:20.171543Z"

      expected_events =
        "Author Create Timestamp Data Type Author-2020-04-21 23:29:20.171519Z1579649360Data-2020-04-21 23:29:20.171538ZType-2020-04-21 23:29:20.171543ZAuthor-2020-04-21 23:25:52.522084Z1579649152Data-2020-04-21 23:25:52.522107ZType-2020-04-21 23:25:52.522111Z"

      assert {:ok, view, html} = live(conn, @url_path)
      assert 4 == find_elements(html, ".events-table__th") |> Enum.count()

      [
        %{
          value: Jason.encode!(@event_1)
        }
      ]
      |> MessageHandler.handle_messages()

      html = render(view)
      actual_event = get_text(html, ".events-index__table")
      assert 1 == find_elements(html, ".events-table__tr") |> Enum.count()
      assert 8 == find_elements(html, ".events-table__cell") |> Enum.count()
      assert expected_event == actual_event

      [
        %{
          value: Jason.encode!(@event_2)
        }
      ]
      |> MessageHandler.handle_messages()

      html = render(view)
      actual_events = get_text(html, ".events-index__table")
      assert 2 == find_elements(html, ".events-table__tr") |> Enum.count()
      assert 12 == find_elements(html, ".events-table__cell") |> Enum.count()
      assert expected_events == actual_events
    end

    test "should show Waiting For The Events when there are no rows to show", %{conn: conn} do
      assert {:ok, _view, html} = live(conn, @url_path)
      MessageHandler.handle_messages([])

      assert get_text(html, ".events-index__title") =~ "All Streaming Events"
      assert get_text(html, ".events-index__table") =~ "Waiting For The Events"
    end
  end

  describe "When form change executes search" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, @url_path)

      [
        %{
          value: Jason.encode!(@event_1)
        },
        %{
          value: Jason.encode!(@event_2)
        }
      ]
      |> MessageHandler.handle_messages()

      %{view: view}
    end

    test "should search and filters events on author", %{view: view} do
      html = render_change(view, :search, %{"search-value" => @event_1["author"]})

      assert get_text(html, ".events-index__table") =~ @event_1["author"]
      refute get_text(html, ".events-index__table") =~ @event_2["author"]
    end

    test "should search and filters events on create timestamp", %{view: view} do
      html = render_change(view, :search, %{"search-value" => @event_1["create_ts"]})

      assert get_text(html, ".events-index__table") =~
               @event_1["create_ts"] |> Integer.to_string()

      refute get_text(html, ".events-index__table") =~
               @event_2["create_ts"] |> Integer.to_string()
    end

    test "should search and filters events on data", %{view: view} do
      html = render_change(view, :search, %{"search-value" => @event_1["data"]})

      assert get_text(html, ".events-index__table") =~ @event_1["data"]
      refute get_text(html, ".events-index__table") =~ @event_2["data"]
    end

    test "should search and filters events on type", %{view: view} do
      html = render_change(view, :search, %{"search-value" => @event_1["type"]})

      assert get_text(html, ".events-index__table") =~ @event_1["type"]
      refute get_text(html, ".events-index__table") =~ @event_2["type"]
    end
  end

  test "shows No Events if no results returned", %{conn: conn} do
    assert {:ok, view, _html} = live(conn, @url_path)
    MessageHandler.handle_messages([])
    html = render_change(view, :search, %{"search-value" => "__NOT_RESULTS_SHOULD RETURN__"})

    assert get_text(html, ".events-index__table") =~ "Waiting For The Events"
  end

  defp find_elements(html, selector) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find(selector)
  end
end
