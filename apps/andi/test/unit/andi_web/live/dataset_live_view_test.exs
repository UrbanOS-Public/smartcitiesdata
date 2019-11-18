defmodule AndiWeb.DatasetLiveViewTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Andi, only: [instance_name: 0]
  import SmartCity.Event, only: [data_ingest_end: 0]
  import SmartCity.TestHelper, only: [eventually: 1]

  alias Andi.DatasetCache

  alias SmartCity.TestDataGenerator, as: TDG

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/live"

  setup do
    GenServer.call(DatasetCache, :reset)
  end

  describe "Basic live page load" do
    test "loads all datasets", %{conn: conn} do
      datasets = Enum.map(1..3, fn _x -> TDG.create_dataset([]) end)

      DatasetCache.put(datasets)

      assert {:ok, _view, html} = live(conn, @url_path)

      table_text = floki_get_text(html, ".datasets-index__table")

      Enum.each(datasets, fn dataset ->
        assert table_text =~ dataset.business.dataTitle
      end)
    end

    test "shows No Datasets when there are no rows to show", %{conn: conn} do
      assert {:ok, view, html} = live(conn, @url_path)

      assert floki_get_text(html, ".datasets-index__title") =~ "All Datasets"
      assert floki_get_text(html, ".datasets-index__table") =~ "No Datasets"
    end
  end

  describe "Live connection with search params in URL" do
    test "populates search box", %{conn: conn} do
      search_text = "Where's Waldo?"

      assert {:ok, view, html} = live(conn, @url_path <> "?search=" <> search_text)
      assert [search_text] = get_search_input_value(html)
    end

    test "filters results based on search", %{conn: conn} do
      dataset_a = TDG.create_dataset(business: %{dataTitle: "data_a"})
      dataset_b = TDG.create_dataset(business: %{dataTitle: "data_b"})

      DatasetCache.put([dataset_a, dataset_b])

      # For most of our tests, we can let live/2 handle both the static connection
      # and the live update. That wasn't working correctly for this one so doing the
      # steps separately fixes the issue.
      conn = get(conn, @url_path)

      assert {:ok, view, html} = live(conn, @url_path <> "?search=" <> dataset_a.business.dataTitle)

      assert floki_get_text(html, ".datasets-index__table") =~ dataset_a.business.dataTitle
      refute floki_get_text(html, ".datasets-index__table") =~ dataset_b.business.dataTitle
    end

    test "updating search field does not override other params", %{conn: conn} do
      conn = get(conn, @url_path)
      {:ok, view, _html} = live(conn, @url_path <> "?order-by=dataTitle&order-dir=asc")

      assert_redirect(view, @url_path <> "?order-by=dataTitle&order-dir=asc&search=search", fn ->
        render_change(view, :search, %{"search-value" => "search"})
      end)
    end
  end

  describe "When form change executes search" do
    test "search filters datasets on orgTitle", %{conn: conn} do
      dataset_a = TDG.create_dataset(business: %{orgTitle: "org_a"})
      dataset_b = TDG.create_dataset(business: %{orgTitle: "org_b"})

      DatasetCache.put([dataset_a, dataset_b])

      {:ok, view, _html} = live(conn, @url_path)

      html = render_change(view, :search, %{"search-value" => dataset_a.business.orgTitle})

      assert floki_get_text(html, ".datasets-index__table") =~ dataset_a.business.orgTitle
      refute floki_get_text(html, ".datasets-index__table") =~ dataset_b.business.orgTitle
    end

    test "search filters datasets on dataTitle", %{conn: conn} do
      dataset_a = TDG.create_dataset(business: %{dataTitle: "data_a"})
      dataset_b = TDG.create_dataset(business: %{dataTitle: "data_b"})

      DatasetCache.put([dataset_a, dataset_b])

      {:ok, view, _html} = live(conn, @url_path)

      html = render_change(view, :search, %{"search-value" => dataset_a.business.dataTitle})

      assert floki_get_text(html, ".datasets-index__table") =~ dataset_a.business.dataTitle
      refute floki_get_text(html, ".datasets-index__table") =~ dataset_b.business.dataTitle
    end

    test "shows No Datasets if no results returned", %{conn: conn} do
      dataset_a = TDG.create_dataset(business: %{dataTitle: "data_a"})
      dataset_b = TDG.create_dataset(business: %{dataTitle: "data_b"})

      DatasetCache.put([dataset_a, dataset_b])

      {:ok, view, _html} = live(conn, @url_path)

      html = render_change(view, :search, %{"search-value" => "__NOT_RESULTS_SHOULD RETURN__"})

      assert floki_get_text(html, ".datasets-index__table") =~ "No Datasets"
    end

    test "Search Change event triggers redirect and updates search box value", %{conn: conn} do
      {:ok, view, _html} = live(conn, @url_path)

      search_text = "Some search"

      assert_redirect(view, @url_path <> "?search=" <> search_text, fn ->
        assert [search_text] ==
                 view
                 |> render_change(:search, %{"search-value" => search_text})
                 |> get_search_input_value()
      end)
    end
  end

  describe "When form submit executes search" do
    test "filters on orgTitle", %{conn: conn} do
      dataset_a = TDG.create_dataset(business: %{orgTitle: "org_a"})
      dataset_b = TDG.create_dataset(business: %{orgTitle: "org_b"})

      DatasetCache.put([dataset_a, dataset_b])

      {:ok, view, _html} = live(conn, @url_path)

      html = render_submit(view, :search, %{"search-value" => dataset_a.business.orgTitle})

      assert floki_get_text(html, ".datasets-index__table") =~ dataset_a.business.orgTitle
      refute floki_get_text(html, ".datasets-index__table") =~ dataset_b.business.orgTitle
    end

    test "filters on dataTitle", %{conn: conn} do
      dataset_a = TDG.create_dataset(business: %{dataTitle: "data_a"})
      dataset_b = TDG.create_dataset(business: %{dataTitle: "data_b"})

      DatasetCache.put([dataset_a, dataset_b])

      {:ok, view, _html} = live(conn, @url_path)

      html = render_submit(view, :search, %{"search-value" => dataset_a.business.dataTitle})

      assert floki_get_text(html, ".datasets-index__table") =~ dataset_a.business.dataTitle
      refute floki_get_text(html, ".datasets-index__table") =~ dataset_b.business.dataTitle
    end

    test "Search Submit event triggers redirect and updates search box value", %{conn: conn} do
      {:ok, view, _html} = live(conn, @url_path)

      search_text = "Some text"

      assert_redirect(view, @url_path <> "?search=" <> search_text, fn ->
        assert [search_text] ==
                 view
                 |> render_submit(:search, %{"search-value" => search_text})
                 |> get_search_input_value()
      end)
    end
  end

  test "data_ingest_end events update ingested time", %{conn: conn} do
    dataset = TDG.create_dataset(%{})

    DatasetCache.put(dataset)
    assert {:ok, view, _html} = live(conn, @url_path)
    table_text = floki_get_text(render(view), ".datasets-index__table")
    IO.inspect(table_text, label: "table text")
    assert not (table_text =~ "check")

    Brook.Test.send(instance_name(), data_ingest_end(), :andi, dataset)

    eventually(fn ->
      table_text = floki_get_text(render(view), ".datasets-index__table")
      IO.inspect(table_text, label: "table text - after")
      assert table_text =~ "check"
    end)
  end

  defp get_search_input_value(html) do
    html
    |> Floki.find("input.datasets-index__search-input")
    |> Floki.attribute("value")
  end

  defp floki_get_text(html, selector) do
    html
    |> Floki.find(selector)
    |> Floki.text()
  end
end
