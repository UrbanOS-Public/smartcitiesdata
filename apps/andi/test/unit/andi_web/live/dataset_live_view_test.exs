defmodule AndiWeb.DatasetLiveViewTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/live"

  test "Live connection works", %{conn: conn} do
    assert {:ok, view, html} = live(conn, @url_path)

    assert html =~ "All Datasets"
  end

  test "Live connection with search param populates search box", %{conn: conn} do
    search_text = "Where's Waldo?"

    assert {:ok, view, html} = live(conn, @url_path <> "?search-value=" <> search_text)
    assert [search_text] = get_search_input_value(html)
  end

  test "Search Change event triggers redirect and updates search box value", %{conn: conn} do
    {:ok, view, _html} = live(conn, @url_path)

    search_text = "Some search"

    assert_redirect(view, @url_path <> "?search-value=" <> search_text, fn ->
      assert [search_text] ==
               view
               |> render_change(:search, %{"search-value" => search_text})
               |> get_search_input_value()
    end)
  end

  test "Search Submit event triggers redirect and updates search box value", %{conn: conn} do
    {:ok, view, _html} = live(conn, @url_path)

    search_text = "Some text"

    assert_redirect(view, @url_path <> "?search-value=" <> search_text, fn ->
      assert [search_text] ==
               view
               |> render_submit(:search, %{"search-value" => search_text})
               |> get_search_input_value()
    end)
  end

  defp get_search_input_value(html) do
    html
    |> Floki.find("input.datasets-search")
    |> Floki.attribute("value")
  end
end
