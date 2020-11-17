defmodule AndiWeb.DatasetLiveViewTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Phoenix.ConnTest
  use Placebo
  alias Andi.Schemas.User

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2, get_values: 2]

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets"
  @user UserHelpers.create_user()

  setup do
    allow(Andi.Repo.get_by(Andi.Schemas.User, any()), return: @user)
    allow(User.get_all(), return: [@user])
    allow(User.get_by_subject_id(any()), return: @user)
    []
  end

  setup %{auth_conn_case: auth_conn_case} do
    auth_conn_case.disable_revocation_list.()
    :ok
  end

  describe "Basic live page load" do
    test "loads all datasets", %{conn: conn} do
      datasets =
        Enum.map(
          1..3,
          fn _x ->
            DatasetHelpers.create_dataset(%{})
          end
        )

      allow(Andi.Repo.all(any()), return: datasets)
      DatasetHelpers.replace_all_datasets_in_repo(datasets)

      assert {:ok, _view, html} = live(conn, @url_path)

      table_text = get_text(html, ".datasets-index__table")

      Enum.each(datasets, fn dataset ->
        assert table_text =~ dataset.business.dataTitle
      end)
    end

    test "shows No Datasets when there are no rows to show", %{conn: conn} do
      allow(Andi.Repo.all(any()), return: [])
      DatasetHelpers.replace_all_datasets_in_repo([])

      assert {:ok, view, html} = live(conn, @url_path)

      assert get_text(html, ".datasets-index__title") =~ "All Datasets"
      assert get_text(html, ".datasets-index__table") =~ "No Datasets"
    end
  end

  describe "Live connection with search params in URL" do
    setup do
      allow(Andi.Repo.all(any()), return: [])

      :ok
    end

    test "populates search box", %{conn: conn} do
      DatasetHelpers.replace_all_datasets_in_repo([])

      search_text = "Where's Waldo?"

      assert {:ok, view, html} = live(conn, @url_path <> "?search=" <> search_text)
      assert [search_text] = get_values(html, "input.datasets-index__search-input")
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
    test "Search Change event triggers redirect and updates search box value", %{conn: conn} do
      allow(Andi.Repo.all(any()), return: [])
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
    test "Search Submit event triggers redirect and updates search box value", %{conn: conn} do
      allow(Andi.Repo.all(any()), return: [])
      DatasetHelpers.replace_all_datasets_in_repo([])

      {:ok, view, _html} = live(conn, @url_path)

      search_text = "Some text"

      assert [search_text] ==
               view
               |> render_submit(:search, %{"search-value" => search_text})
               |> get_values("input.datasets-index__search-input")

      assert_redirect(view, @url_path <> "?search=" <> search_text)
    end
  end

  describe "Toggle remote datasets checkbox" do
    test "excludes remotes by default", %{conn: conn} do
      dataset_a = DatasetHelpers.create_dataset(technical: %{sourceType: "ingest"})
      dataset_b = DatasetHelpers.create_dataset(technical: %{sourceType: "remote"})

      allow(Andi.Repo.all(any()), return: [dataset_a, dataset_b])
      DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

      {:ok, _view, html} = live(conn, @url_path)

      assert get_text(html, ".datasets-index__table") =~ dataset_a.business.dataTitle
      refute get_text(html, ".datasets-index__table") =~ dataset_b.business.dataTitle
    end

    test "toggles inclusion of remotes when button is clicked", %{conn: conn} do
      dataset_a = DatasetHelpers.create_dataset(technical: %{sourceType: "ingest"})
      dataset_b = DatasetHelpers.create_dataset(technical: %{sourceType: "remote"})

      allow(Andi.Repo.all(any()), return: [dataset_a, dataset_b])
      DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

      {:ok, view, _html} = live(conn, @url_path)

      html = render_click(view, :toggle_remotes)

      assert get_text(html, ".datasets-index__table") =~ dataset_a.business.dataTitle
      assert get_text(html, ".datasets-index__table") =~ dataset_b.business.dataTitle
    end
  end

  describe "Toggle submitted datasets checkbox" do
    test "includes datasets that are not just submitted, by default", %{conn: conn} do
      dataset_a =
        DatasetHelpers.create_dataset(%{})
        |> Map.put(:submission_status, :approved)

      dataset_b =
        DatasetHelpers.create_dataset(%{})
        |> Map.put(:submission_status, :submitted)

      allow(Andi.Repo.all(any()), return: [dataset_a, dataset_b])
      DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

      {:ok, _view, html} = live(conn, @url_path)

      assert get_text(html, ".datasets-index__table") =~ dataset_a.business.dataTitle
      assert get_text(html, ".datasets-index__table") =~ dataset_b.business.dataTitle
    end

    test "toggles exclusion of non-submitted datasets when checked", %{conn: conn} do
      dataset_a =
        DatasetHelpers.create_dataset(%{})
        |> Map.put(:submission_status, :approved)

      dataset_b =
        DatasetHelpers.create_dataset(%{})
        |> Map.put(:submission_status, :submitted)

      allow(Andi.Repo.all(any()), return: [dataset_a, dataset_b])
      DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

      {:ok, view, _html} = live(conn, @url_path)

      html = render_click(view, :toggle_submitted)

      refute get_text(html, ".datasets-index__table") =~ dataset_a.business.dataTitle
      assert get_text(html, ".datasets-index__table") =~ dataset_b.business.dataTitle
    end
  end
end
