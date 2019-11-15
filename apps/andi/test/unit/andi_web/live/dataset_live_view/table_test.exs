defmodule AndiWeb.DatasetLiveViewTest.TableTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Andi.DatasetCache

  alias SmartCity.TestDataGenerator, as: TDG

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/live"

  @ingested_time_a "123123213"
  @ingested_time_b "454699234"

  setup do
    GenServer.call(DatasetCache, :reset)
  end

  describe "order by click" do
    setup %{conn: conn} do
      dataset_a = TDG.create_dataset(business: %{orgTitle: "org_b", dataTitle: "data_a"})
      dataset_b = TDG.create_dataset(business: %{orgTitle: "org_a", dataTitle: "data_b"})

      DatasetCache.put([dataset_a, dataset_b])

      DatasetCache.put([
        %{"id" => dataset_a.id, "ingested_time" => @ingested_time_a},
        %{"id" => dataset_b.id, "ingested_time" => @ingested_time_b}
      ])

      {:ok, view, _} =
        get(conn, @url_path)
        |> live()

      row_a = ["check", dataset_a.business.dataTitle, dataset_a.business.orgTitle]
      row_b = ["check", dataset_b.business.dataTitle, dataset_b.business.orgTitle]

      {:ok, %{view: view, row_a: row_a, row_b: row_b}}
    end

    test "dataTitle descending", %{view: view, row_a: row_a, row_b: row_b} do
      render_click([view, "datasets_table"], "order-by", %{"field" => "data_title"})
      html = render(view)

      assert get_rendered_table_cells(html) == [row_b, row_a]
    end

    test "orgTitle ascending", %{view: view, row_a: row_a, row_b: row_b} do
      render_click([view, "datasets_table"], "order-by", %{"field" => "org_title"})
      html = render(view)

      assert get_rendered_table_cells(html) == [row_b, row_a]
    end

    test "orgTitle descending", %{view: view, row_a: row_a, row_b: row_b} do
      render_click([view, "datasets_table"], "order-by", %{"field" => "org_title"})
      render_click([view, "datasets_table"], "order-by", %{"field" => "org_title"})
      html = render(view)

      assert get_rendered_table_cells(html) == [row_a, row_b]
    end

    test "ingested status ascending", %{view: view, row_a: row_a, row_b: row_b} do
      render_click([view, "datasets_table"], "order-by", %{"field" => "ingested_time"})
      html = render(view)

      assert get_rendered_table_cells(html) == [row_a, row_b]
    end

    test "ingested status descending", %{view: view, row_a: row_a, row_b: row_b} do
      render_click([view, "datasets_table"], "order-by", %{"field" => "ingested_time"})
      render_click([view, "datasets_table"], "order-by", %{"field" => "ingested_time"})
      html = render(view)

      assert get_rendered_table_cells(html) == [row_b, row_a]
    end
  end

  describe "order by url params" do
    setup %{conn: conn} do
      dataset_a = TDG.create_dataset(business: %{orgTitle: "org_a", dataTitle: "data_b"})
      dataset_b = TDG.create_dataset(business: %{orgTitle: "org_b", dataTitle: "data_a"})

      DatasetCache.put([dataset_a, dataset_b])

      DatasetCache.put([
        %{"id" => dataset_a.id, "ingested_time" => @ingested_time_a},
        %{"id" => dataset_b.id, "ingested_time" => @ingested_time_b}
      ])

      conn = get(conn, @url_path)

      row_a = ["check", dataset_a.business.dataTitle, dataset_a.business.orgTitle]
      row_b = ["check", dataset_b.business.dataTitle, dataset_b.business.orgTitle]

      {:ok, %{conn: conn, row_a: row_a, row_b: row_b}}
    end

    test "defaults to data title ascending", %{conn: conn, row_a: row_a, row_b: row_b} do
      {:ok, _view, html} = live(conn, @url_path)

      assert get_rendered_table_cells(html) == [row_b, row_a]
    end

    test "data title descending", %{conn: conn, row_a: row_a, row_b: row_b} do
      {:ok, _view, html} = live(conn, @url_path <> "?order-by=data_title&order-dir=desc")

      assert get_rendered_table_cells(html) == [row_a, row_b]
    end

    test "org title ascending", %{conn: conn, row_a: row_a, row_b: row_b} do
      {:ok, _view, html} = live(conn, @url_path <> "?order-by=org_title")

      assert get_rendered_table_cells(html) == [row_a, row_b]
    end
  end

  test "ordering does not affect other query params", %{conn: conn} do
    dataset_a = TDG.create_dataset(business: %{orgTitle: "org_a", dataTitle: "data_b"})
    dataset_b = TDG.create_dataset(business: %{orgTitle: "org_b", dataTitle: "data_a"})

    DatasetCache.put([dataset_a, dataset_b])

    conn = get(conn, @url_path)
    {:ok, view, _html} = live(conn, @url_path <> "?foo=bar")

    assert_redirect(view, @url_path <> "?foo=bar&order-by=data_title&order-dir=desc", fn ->
      render_click([view, "datasets_table"], "order-by", %{"field" => "data_title"})
    end)
  end

  test "ingested_time is optional", %{conn: conn} do
    dataset = TDG.create_dataset(%{})

    DatasetCache.put(dataset)

    {:ok, _view, html} = live(conn, @url_path)

    assert get_rendered_table_cells(html) == [["", dataset.business.dataTitle, dataset.business.orgTitle]]
  end

  defp get_rendered_table_cells(html) do
    Floki.find(html, ".datasets-table__tr")
    |> Enum.map(fn {_name, _attrs, children} ->
      Enum.map(children, fn {_name, _attrs, children} ->
        Floki.text(children)
      end)
    end)
  end
end
