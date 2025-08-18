defmodule AndiWeb.DatasetLiveViewTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  alias Andi.Schemas.User

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2, get_values: 2]

  @moduletag timeout: 5000

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets"
  @user UserHelpers.create_user()

  setup do
    # Set up :meck for modules without dependency injection
    modules_to_mock = [Andi.Repo, User, Guardian.DB.Token]
    
    # Clean up any existing mocks first
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.unload(module)
      catch
        _, _ -> :ok
      end
    end)
    
    # Set up fresh mocks
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.new(module, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
    end)
    
    # Default expectations
    :meck.expect(Andi.Repo, :get_by, fn Andi.Schemas.User, _ -> @user end)
    :meck.expect(User, :get_all, fn -> [@user] end)
    :meck.expect(User, :get_by_subject_id, fn _ -> @user end)
    :meck.expect(Guardian.DB.Token, :find_by_claims, fn _ -> nil end)
    
    on_exit(fn ->
      Enum.each(modules_to_mock, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)
    end)
    
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

      :meck.expect(Andi.Repo, :all, fn _ -> datasets end)
      DatasetHelpers.replace_all_datasets_in_repo(datasets)

      assert {:ok, _view, html} = live(conn, @url_path)

      table_text = get_text(html, ".datasets-index__table")

      Enum.each(datasets, fn dataset ->
        assert table_text =~ dataset.business.dataTitle
      end)
    end

    test "shows No Datasets when there are no rows to show", %{conn: conn} do
      :meck.expect(Andi.Repo, :all, fn _ -> [] end)
      DatasetHelpers.replace_all_datasets_in_repo([])

      assert {:ok, _view, html} = live(conn, @url_path)

      assert get_text(html, ".datasets-index__title") =~ "All Datasets"
      assert get_text(html, ".datasets-index__table") =~ "No Datasets"
    end
  end

  describe "Live connection with search params in URL" do
    setup do
      :meck.expect(Andi.Repo, :all, fn _ -> [] end)
      :ok
    end

    test "populates search box", %{conn: conn} do
      DatasetHelpers.replace_all_datasets_in_repo([])

      search_text = "Where's Waldo?"

      assert {:ok, _view, html} = live(conn, @url_path <> "?search=" <> search_text)
      assert [^search_text] = get_values(html, "input.datasets-index__search-input")
    end

    test "updating search field does not override other params", %{conn: conn} do
      DatasetHelpers.replace_all_datasets_in_repo([])
      conn = get(conn, @url_path)
      {:ok, view, _html} = live(conn, @url_path <> "?order-by=dataTitle&order-dir=asc")

      render_change(view, :search, %{"search-value" => "search"})
      assert_patch(view, @url_path <> "?order-by=dataTitle&order-dir=asc&search=search")
    end
  end

  describe "When form change executes search" do
    test "Search Change event triggers redirect and updates search box value", %{conn: conn} do
      :meck.expect(Andi.Repo, :all, fn _ -> [] end)
      DatasetHelpers.replace_all_datasets_in_repo([])

      {:ok, view, _html} = live(conn, @url_path)

      search_text = "Some search"

      assert [search_text] ==
               view
               |> render_change(:search, %{"search-value" => search_text})
               |> get_values("input.datasets-index__search-input")

      assert_patch(view, encoded(@url_path <> "?search=" <> search_text))
    end
  end

  describe "When form submit executes search" do
    test "Search Submit event triggers redirect and updates search box value", %{conn: conn} do
      :meck.expect(Andi.Repo, :all, fn _ -> [] end)
      DatasetHelpers.replace_all_datasets_in_repo([])

      {:ok, view, _html} = live(conn, @url_path)

      search_text = "Some text"

      assert [search_text] ==
               view
               |> render_submit(:search, %{"search-value" => search_text})
               |> get_values("input.datasets-index__search-input")

      assert_patch(view, encoded(@url_path <> "?search=" <> search_text))
    end
  end

  describe "Toggle remote datasets checkbox" do
    test "excludes remotes by default", %{conn: conn} do
      dataset_a = DatasetHelpers.create_dataset(technical: %{sourceType: "ingest"})
      dataset_b = DatasetHelpers.create_dataset(technical: %{sourceType: "remote"})

      :meck.expect(Andi.Repo, :all, fn _ -> [dataset_a, dataset_b] end)
      DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

      {:ok, _view, html} = live(conn, @url_path)

      assert get_text(html, ".datasets-index__table") =~ dataset_a.business.dataTitle
      refute get_text(html, ".datasets-index__table") =~ dataset_b.business.dataTitle
    end

    test "toggles inclusion of remotes when button is clicked", %{conn: conn} do
      dataset_a = DatasetHelpers.create_dataset(technical: %{sourceType: "ingest"})
      dataset_b = DatasetHelpers.create_dataset(technical: %{sourceType: "remote"})

      :meck.expect(Andi.Repo, :all, fn _ -> [dataset_a, dataset_b] end)
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

      :meck.expect(Andi.Repo, :all, fn _ -> [dataset_a, dataset_b] end)
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

      :meck.expect(Andi.Repo, :all, fn _ -> [dataset_a, dataset_b] end)
      DatasetHelpers.replace_all_datasets_in_repo([dataset_a, dataset_b])

      {:ok, view, _html} = live(conn, @url_path)

      html = render_click(view, :toggle_submitted)

      refute get_text(html, ".datasets-index__table") =~ dataset_a.business.dataTitle
      assert get_text(html, ".datasets-index__table") =~ dataset_b.business.dataTitle
    end
  end

  defp encoded(url) do
    String.replace(url, " ", "+")
  end
end
