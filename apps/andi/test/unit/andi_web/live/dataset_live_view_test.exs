defmodule AndiWeb.DatasetLiveViewTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  use Placebo

  import Phoenix.LiveViewTest

  import FlokiHelpers,
    only: [
      get_text: 2,
      get_values: 2,
      find_elements: 2
    ]

  alias Andi.InputSchemas.Datasets.Dataset

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets"

  describe "Basic live page load" do
    test "loads all datasets", %{conn: conn} do
      datasets =
        Enum.map(
          1..3,
          fn _x ->
            DatasetHelpers.create_dataset(%{})
          end
        )

      DatasetHelpers.replace_all_datasets_in_repo(datasets)

      assert {:ok, _view, html} = live(conn, @url_path)

      table_text = get_text(html, ".datasets-index__table")

      Enum.each(datasets, fn dataset ->
        assert table_text =~ dataset.business.dataTitle
      end)
    end

    test "shows No Datasets when there are no rows to show", %{conn: conn} do
      DatasetHelpers.replace_all_datasets_in_repo([])

      assert {:ok, view, html} = live(conn, @url_path)

      assert get_text(html, ".datasets-index__title") =~ "All Datasets"
      assert get_text(html, ".datasets-index__table") =~ "No Datasets"
    end

    test "does not load datasets that only contain a timestamp", %{conn: conn} do
      dataset_with_only_timestamp = %Dataset{
        id: UUID.uuid4(),
        ingestedTime: DateTime.utc_now(),
        business: %{},
        technical: %{}
      }

      datasets =
        Enum.map(
          1..3,
          fn _x ->
            DatasetHelpers.create_dataset(%{})
          end
        )

      DatasetHelpers.replace_all_datasets_in_repo(datasets ++ [dataset_with_only_timestamp])

      assert {:ok, _view, html} = live(conn, @url_path)
      table_text = get_text(html, ".datasets-index__table")

      assert 3 == find_elements(html, ".datasets-index__table tr") |> Enum.count()

      Enum.each(datasets, fn dataset ->
        assert table_text =~ dataset.business.dataTitle
      end)
    end
  end

  describe "Live connection with search params in URL" do
    test "populates search box", %{conn: conn} do
      DatasetHelpers.replace_all_datasets_in_repo([])

      search_text = "Where's Waldo?"

      assert {:ok, view, html} = live(conn, @url_path <> "?search=" <> search_text)
      assert [search_text] = get_values(html, "input.datasets-index__search-input")
    end

    test "filters results based on search", %{conn: conn} do
      dataset_a = DatasetHelpers.create_dataset(business: %{dataTitle: "data_a"})
      dataset_b = DatasetHelpers.create_dataset(business: %{dataTitle: "data_b"})

      DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

      # For most of our tests, we can let live/2 handle both the static connection
      # and the live update. That wasn't working correctly for this one so doing the
      # steps separately fixes the issue.
      conn = get(conn, @url_path)

      assert {:ok, view, html} = live(conn, @url_path <> "?search=" <> dataset_a.business.dataTitle)

      assert get_text(html, ".datasets-index__table") =~ dataset_a.business.dataTitle
      refute get_text(html, ".datasets-index__table") =~ dataset_b.business.dataTitle
    end

    test "updating search field does not override other params", %{conn: conn} do
      DatasetHelpers.replace_all_datasets_in_repo([])
      conn = get(conn, @url_path)
      {:ok, view, _html} = live(conn, @url_path <> "?order-by=dataTitle&order-dir=asc")

      render_change(view, :search, %{"search-value" => "search"})
      assert_redirect(view, @url_path <> "?order-by=dataTitle&order-dir=asc&search=search")
    end
  end

  describe "When form change executes search" do
    test "search filters datasets on orgTitle", %{conn: conn} do
      dataset_a = DatasetHelpers.create_dataset(business: %{orgTitle: "org_a"})
      dataset_b = DatasetHelpers.create_dataset(business: %{orgTitle: "org_b"})

      DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

      {:ok, view, _html} = live(conn, @url_path)

      html = render_change(view, :search, %{"search-value" => dataset_a.business.orgTitle})

      assert get_text(html, ".datasets-index__table") =~ dataset_a.business.orgTitle
      refute get_text(html, ".datasets-index__table") =~ dataset_b.business.orgTitle
    end

    test "search filters datasets on dataTitle", %{conn: conn} do
      dataset_a = DatasetHelpers.create_dataset(business: %{dataTitle: "data_a"})
      dataset_b = DatasetHelpers.create_dataset(business: %{dataTitle: "data_b"})

      DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

      {:ok, view, _html} = live(conn, @url_path)

      html = render_change(view, :search, %{"search-value" => dataset_a.business.dataTitle})

      assert get_text(html, ".datasets-index__table") =~ dataset_a.business.dataTitle
      refute get_text(html, ".datasets-index__table") =~ dataset_b.business.dataTitle
    end

    test "shows No Datasets if no results returned", %{conn: conn} do
      dataset_a = DatasetHelpers.create_dataset(business: %{dataTitle: "data_a"})
      dataset_b = DatasetHelpers.create_dataset(business: %{dataTitle: "data_b"})

      DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

      {:ok, view, _html} = live(conn, @url_path)

      html = render_change(view, :search, %{"search-value" => "__NOT_RESULTS_SHOULD RETURN__"})

      assert get_text(html, ".datasets-index__table") =~ "No Datasets"
    end

    test "Search Change event triggers redirect and updates search box value", %{conn: conn} do
      DatasetHelpers.replace_all_datasets_in_repo([])

      {:ok, view, _html} = live(conn, @url_path)

      search_text = "Some search"

      assert [search_text] ==
               view
               |> render_change(:search, %{"search-value" => search_text})
               |> get_values("input.datasets-index__search-input")

      assert_redirect(view, @url_path <> "?search=" <> search_text)
    end
  end

  describe "When form submit executes search" do
    test "filters on orgTitle", %{conn: conn} do
      dataset_a = DatasetHelpers.create_dataset(business: %{orgTitle: "org_a"})
      dataset_b = DatasetHelpers.create_dataset(business: %{orgTitle: "org_b"})

      DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

      {:ok, view, _html} = live(conn, @url_path)

      html = render_submit(view, :search, %{"search-value" => dataset_a.business.orgTitle})

      assert get_text(html, ".datasets-index__table") =~ dataset_a.business.orgTitle
      refute get_text(html, ".datasets-index__table") =~ dataset_b.business.orgTitle
    end

    test "filters on dataTitle", %{conn: conn} do
      dataset_a = DatasetHelpers.create_dataset(business: %{dataTitle: "data_a"})
      dataset_b = DatasetHelpers.create_dataset(business: %{dataTitle: "data_b"})

      DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

      {:ok, view, _html} = live(conn, @url_path)

      html = render_submit(view, :search, %{"search-value" => dataset_a.business.dataTitle})

      assert get_text(html, ".datasets-index__table") =~ dataset_a.business.dataTitle
      refute get_text(html, ".datasets-index__table") =~ dataset_b.business.dataTitle
    end

    test "Search Submit event triggers redirect and updates search box value", %{conn: conn} do
      DatasetHelpers.replace_all_datasets_in_repo([])

      {:ok, view, _html} = live(conn, @url_path)

      search_text = "Some text"

      assert [search_text] ==
               view
               |> render_submit(:search, %{"search-value" => search_text})
               |> get_values("input.datasets-index__search-input")

      assert_redirect(view, @url_path <> "?search=" <> search_text)
    end

    test "Search Submit succeeds even with missing fields", %{conn: conn} do
      dataset_a =
        DatasetHelpers.create_dataset(business: %{orgTitle: "org_a"})
        |> put_in([:business, :dataTitle], nil)

      dataset_b =
        DatasetHelpers.create_dataset(business: %{dataTitle: "data_b"})
        |> put_in([:business, :orgTitle], nil)

      DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

      {:ok, view, _html} = live(conn, @url_path)

      html = render_submit(view, :search, %{"search-value" => dataset_a.business.orgTitle})

      assert get_text(html, ".datasets-index__table") =~ dataset_a.business.orgTitle
      refute get_text(html, ".datasets-index__table") =~ dataset_b.business.dataTitle
    end
  end

  describe "Toggle remote datasets checkbox" do
    test "excludes remotes by default", %{conn: conn} do
      dataset_a = DatasetHelpers.create_dataset(technical: %{sourceType: "ingest"})
      dataset_b = DatasetHelpers.create_dataset(technical: %{sourceType: "remote"})

      DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

      {:ok, _view, html} = live(conn, @url_path)

      assert get_text(html, ".datasets-index__table") =~ dataset_a.business.dataTitle
      refute get_text(html, ".datasets-index__table") =~ dataset_b.business.dataTitle
    end

    test "toggles inclusion of remotes when button is clicked", %{conn: conn} do
      dataset_a = DatasetHelpers.create_dataset(technical: %{sourceType: "ingest"})
      dataset_b = DatasetHelpers.create_dataset(technical: %{sourceType: "remote"})

      DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

      {:ok, view, _html} = live(conn, @url_path)

      html = render_click(view, :toggle_remotes)

      assert get_text(html, ".datasets-index__table") =~ dataset_a.business.dataTitle
      assert get_text(html, ".datasets-index__table") =~ dataset_b.business.dataTitle
    end
  end
end
