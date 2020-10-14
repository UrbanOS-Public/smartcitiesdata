defmodule AndiWeb.DatasetLiveViewTest.TableTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  use Placebo

  import Phoenix.LiveViewTest

  import FlokiHelpers,
    only: [
      get_attributes: 3
    ]

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets"
  @user UserHelpers.create_user()

  @ingested_time_a "123123213"
  @ingested_time_b "454699234"

  setup do
    allow(Andi.Repo.get_by(Andi.Schemas.User, any()), return: @user)
    [conn: Andi.Test.AuthHelper.build_authorized_conn()]
  end

  describe "order by click" do
    setup %{conn: conn} do
      dataset_a =
        DatasetHelpers.create_dataset(business: %{orgTitle: "org_b", dataTitle: "data_a"})
        |> Map.put(:ingestedTime, @ingested_time_a)

      dataset_b =
        DatasetHelpers.create_dataset(business: %{orgTitle: "org_a", dataTitle: "data_b"})
        |> Map.put(:ingestedTime, @ingested_time_b)

      DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

      allow(Andi.Repo.all(any()), return: [dataset_a, dataset_b])

      {:ok, view, _} =
        get(conn, @url_path)
        |> live()

      row_a = ["Success", dataset_a.business.dataTitle, dataset_a.business.orgTitle, "Edit"]
      row_b = ["Success", dataset_b.business.dataTitle, dataset_b.business.orgTitle, "Edit"]

      {:ok, %{view: view, row_a: row_a, row_b: row_b}}
    end

    test "dataTitle descending", %{view: view, row_a: row_a, row_b: row_b} do
      render_click(view, "order-by", %{"field" => "data_title"})
      html = render(view)

      assert get_rendered_table_cells(html) == [row_b, row_a]
    end

    test "orgTitle ascending", %{view: view, row_a: row_a, row_b: row_b} do
      render_click(view, "order-by", %{"field" => "org_title"})
      html = render(view)

      assert get_rendered_table_cells(html) == [row_b, row_a]
    end

    test "orgTitle descending", %{view: view, row_a: row_a, row_b: row_b} do
      render_click(view, "order-by", %{"field" => "org_title"})
      render_click(view, "order-by", %{"field" => "org_title"})
      html = render(view)

      assert get_rendered_table_cells(html) == [row_a, row_b]
    end

    test "ingested status ascending", %{view: view, row_a: row_a, row_b: row_b} do
      render_click(view, "order-by", %{"field" => "ingested_time"})
      html = render(view)

      assert get_rendered_table_cells(html) == [row_a, row_b]
    end

    test "ingested status descending", %{view: view, row_a: row_a, row_b: row_b} do
      render_click(view, "order-by", %{"field" => "ingested_time"})
      render_click(view, "order-by", %{"field" => "ingested_time"})
      html = render(view)

      assert get_rendered_table_cells(html) == [row_b, row_a]
    end
  end

  describe "order by url params" do
    setup %{conn: conn} do
      dataset_a =
        DatasetHelpers.create_dataset(business: %{orgTitle: "org_a", dataTitle: "data_b"})
        |> Map.put(:ingestedTime, @ingested_time_a)

      dataset_b =
        DatasetHelpers.create_dataset(business: %{orgTitle: "org_b", dataTitle: "data_a"})
        |> Map.put(:ingestedTime, @ingested_time_b)

      allow(Andi.Repo.all(any()), return: [dataset_a, dataset_b])

      DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

      conn = get(conn, @url_path)

      row_a = ["Success", dataset_a.business.dataTitle, dataset_a.business.orgTitle, "Edit"]
      row_b = ["Success", dataset_b.business.dataTitle, dataset_b.business.orgTitle, "Edit"]

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
    dataset_a = DatasetHelpers.create_dataset(business: %{orgTitle: "org_a", dataTitle: "data_b"})
    dataset_b = DatasetHelpers.create_dataset(business: %{orgTitle: "org_b", dataTitle: "data_a"})

    allow(Andi.Repo.all(any()), return: [dataset_a, dataset_b])
    DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

    conn = get(conn, @url_path)
    {:ok, view, _html} = live(conn, @url_path <> "?foo=bar")

    render_click(view, "order-by", %{"field" => "data_title"})
    assert_redirect(view, @url_path <> "?foo=bar&order-by=data_title&order-dir=desc")
  end

  test "ingested_time is optional", %{conn: conn} do
    dataset = DatasetHelpers.create_dataset(%{})

    allow(Andi.Repo.all(any()), return: [dataset])
    DatasetHelpers.replace_all_datasets_in_repo([dataset])

    {:ok, _view, html} = live(conn, @url_path)

    assert get_rendered_table_cells(html) == [["", dataset.business.dataTitle, dataset.business.orgTitle, "Edit"]]
  end

  test "edit buttons link to dataset edit", %{conn: conn} do
    dataset = DatasetHelpers.create_dataset(%{})

    allow(Andi.Repo.all(any()), return: [dataset])
    DatasetHelpers.replace_all_datasets_in_repo([dataset])

    {:ok, _view, html} = live(conn, @url_path)

    assert get_attributes(html, ".btn", "href") == ["#{@url_path}/#{dataset.id}"]
  end

  defp get_rendered_table_cells(html) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find(".datasets-table__tr")
    |> Enum.map(fn {_name, _attrs, children} ->
      Enum.map(children, fn {_name, _attrs, children} ->
        Floki.text(children)
      end)
    end)
  end
end
