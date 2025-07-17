defmodule EstuaryWeb.StreamingEventLiveViewTest do
  use ExUnit.Case
  use EstuaryWeb.ConnCase
  import Mox
  import Phoenix.LiveViewTest

  import FlokiHelpers, only: [get_text: 2]

  alias Estuary.MessageHandler

  setup :set_mox_global
  setup :verify_on_exit!

  @url_path "/streaming-events"
  @event_1 %{
    "author" => "Author-2020-04-21 23:29:20.171519Z",
    "create_ts" => 1_579_649_360,
    "data" => "Data-2020-04-21 23:29:20.171538Z",
    "type" => "Type-2020-04-21 23:29:20.171543Z"
  }

  test "should show Waiting For The Events when there are no rows to show", %{conn: conn} do
    expect(MessageHandler.Mock, :handle_messages, fn _ -> :ok end)
    assert {:ok, _view, html} = live(conn, @url_path)

    assert get_text(html, ".events-index__title") =~ "All Streaming Events"
    assert get_text(html, ".events-index__table") =~ "Waiting For The Events"
  end

  defp find_elements(html, selector) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find(selector)
  end
end