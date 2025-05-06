defmodule AndiWeb.DatasetLiveViewTest.TableTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  alias Andi.Schemas.User
  alias Andi.InputSchemas.MessageErrors

  import Phoenix.LiveViewTest
  import Mock
  import FlokiHelpers,
    only: [
      get_attributes: 3
    ]

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets"
  @user UserHelpers.create_user()

  @ingested_time_a DateTime.from_iso8601("2020-10-01T00:00:00Z") |> elem(1)
  @ingested_time_b DateTime.from_iso8601("2020-11-01T00:00:00Z") |> elem(1)
  @dataset_a DatasetHelpers.create_dataset(business: %{orgTitle: "org_d", dataTitle: "data_a"}) |> Map.put(:ingestedTime, @ingested_time_a)
  @dataset_b DatasetHelpers.create_dataset(business: %{orgTitle: "org_c", dataTitle: "data_b"}) |> Map.put(:ingestedTime, @ingested_time_b)
  @dataset_c DatasetHelpers.create_dataset(business: %{orgTitle: "org_b", dataTitle: "data_c"}) |> Map.put(:ingestedTime, nil) |> Map.put(:submission_status, :rejected)
  @dataset_d DatasetHelpers.create_dataset(business: %{orgTitle: "org_a", dataTitle: "data_d"}) |> Map.put(:ingestedTime, nil) |> Map.put(:submission_status, :approved)

  setup_with_mocks [
    {User, [], [
      get_all: fn() -> [@user] end,
      get_by_subject_id: fn(_) -> @user end
    ]},
    {Andi.Repo, [], [all: fn(_) -> [@dataset_a, @dataset_b, @dataset_c, @dataset_d] end]},
    {Guardian.DB.Token, [], [find_by_claims: fn(_) -> nil end]}
  ], %{conn: conn} do

    DatasetHelpers.replace_all_datasets_in_repo([@dataset_a, @dataset_b])

    allow(MessageErrors.get_latest_error(dataset_a.id), return: create_message_error(dataset_a.id))
    allow(MessageErrors.get_latest_error(dataset_b.id), return: create_message_error(dataset_b.id))
    allow(MessageErrors.get_latest_error(dataset_c.id), return: create_message_error(dataset_c.id))
    allow(MessageErrors.get_latest_error(dataset_d.id), return: create_message_error(dataset_d.id))

    {:ok, view, _} =
      get(conn, @url_path)
      |> live()

    row_a = ["Success", @dataset_a.business.dataTitle, @dataset_a.business.orgTitle, "Edit"]
    row_b = ["Success", @dataset_b.business.dataTitle, @dataset_b.business.orgTitle, "Edit"]
    row_c = ["Rejected", @dataset_c.business.dataTitle, @dataset_c.business.orgTitle, "Edit"]
    row_d = ["Approved", @dataset_d.business.dataTitle, @dataset_d.business.orgTitle, "Edit"]

    {:ok, %{view: view, row_a: row_a, row_b: row_b, row_c: row_c, row_d: row_d}}
  end

  describe "order by click" do
    test "dataTitle descending", %{view: view, row_a: row_a, row_b: row_b, row_c: row_c, row_d: row_d} do
      render_click(view, "order-by", %{"field" => "data_title"})
      html = render(view)

      assert get_rendered_table_cells(html) == [row_d, row_c, row_b, row_a]
    end

    test "orgTitle ascending", %{view: view, row_a: row_a, row_b: row_b, row_c: row_c, row_d: row_d} do
      render_click(view, "order-by", %{"field" => "org_title"})
      html = render(view)

      assert get_rendered_table_cells(html) == [row_d, row_c, row_b, row_a]
    end

    test "orgTitle descending", %{view: view, row_a: row_a, row_b: row_b, row_c: row_c, row_d: row_d} do
      render_click(view, "order-by", %{"field" => "org_title"})
      render_click(view, "order-by", %{"field" => "org_title"})
      html = render(view)

      assert get_rendered_table_cells(html) == [row_a, row_b, row_c, row_d]
    end

    test "status ascending", %{view: view, row_a: row_a, row_b: row_b, row_c: row_c, row_d: row_d} do
      render_click(view, "order-by", %{"field" => "status"})
      html = render(view)

      assert get_rendered_table_cells(html) == [row_d, row_c, row_a, row_b]
    end

    test "status descending", %{view: view, row_a: row_a, row_b: row_b, row_c: row_c, row_d: row_d} do
      render_click(view, "order-by", %{"field" => "status"})
      render_click(view, "order-by", %{"field" => "status"})
      html = render(view)

      assert get_rendered_table_cells(html) == [row_a, row_b, row_c, row_d]
    end
  end

  describe "order by url params" do
    test "defaults to data title ascending", %{conn: conn, row_a: row_a, row_b: row_b, row_c: row_c, row_d: row_d} do
      {:ok, _view, html} = live(conn, @url_path)

      assert get_rendered_table_cells(html) == [row_a, row_b, row_c, row_d]
    end

    test "data title descending", %{conn: conn, row_a: row_a, row_b: row_b, row_c: row_c, row_d: row_d} do
      {:ok, _view, html} = live(conn, @url_path <> "?order-by=data_title&order-dir=desc")

      assert get_rendered_table_cells(html) == [row_d, row_c, row_b, row_a]
    end

    test "org title ascending", %{conn: conn, row_a: row_a, row_b: row_b, row_c: row_c, row_d: row_d} do
      {:ok, _view, html} = live(conn, @url_path <> "?order-by=org_title")

      assert get_rendered_table_cells(html) == [row_d, row_c, row_b, row_a]
    end

    test "org title descending", %{conn: conn, row_a: row_a, row_b: row_b, row_c: row_c, row_d: row_d} do
      {:ok, _view, html} = live(conn, @url_path <> "?order-by=org_title&order-dir=desc")

      assert get_rendered_table_cells(html) == [row_a, row_b, row_c, row_d]
    end

    test "status ascending", %{conn: conn, row_a: row_a, row_b: row_b, row_c: row_c, row_d: row_d} do
      {:ok, _view, html} = live(conn, @url_path <> "?order-by=status")

      assert get_rendered_table_cells(html) == [row_d, row_c, row_a, row_b]
    end

    test "status descending", %{conn: conn, row_a: row_a, row_b: row_b, row_c: row_c, row_d: row_d} do
      {:ok, _view, html} = live(conn, @url_path <> "?order-by=status&order-dir=desc")

      assert get_rendered_table_cells(html) == [row_a, row_b, row_c, row_d]
    end

    test "ordering does not affect other query params", %{conn: conn} do
      conn = get(conn, @url_path)
      {:ok, view, _html} = live(conn, @url_path <> "?foo=bar")

      render_click(view, "order-by", %{"field" => "data_title"})
      assert_patch(view, @url_path <> "?foo=bar&order-by=data_title&order-dir=desc")
    end
  end

  describe "table setup" do
    test "edit buttons link to dataset edit", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{})

      with_mock(Andi.Repo, [all: fn(_) -> [dataset] end]) do
        DatasetHelpers.replace_all_datasets_in_repo([dataset])

        {:ok, _view, html} = live(conn, @url_path)

        assert get_attributes(html, ".btn", "href") == ["#{@url_path}/#{dataset.id}"]
      end
    end
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

  defp create_message_error(dataset_id) do
    %{
      dataset_id: dataset_id,
      has_current_error: false,
      last_error_time: DateTime.from_unix!(0)
    }
  end
end
