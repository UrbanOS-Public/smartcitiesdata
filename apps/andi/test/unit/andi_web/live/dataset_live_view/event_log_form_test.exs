defmodule AndiWeb.EventLogFormTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo
  alias Andi.Schemas.User
  alias SmartCity.TestDataGenerator, as: TDG
  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2, get_values: 2]

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/"

  defp allowAuthUser do
    allow(Andi.Repo.get_by(Andi.Schemas.User, any()), return: @user)
    allow(User.get_all(), return: [@user])
    allow(User.get_by_subject_id(any()), return: @user)
  end

  setup do
    allowAuthUser()
    []
  end

  setup %{auth_conn_case: auth_conn_case} do
    auth_conn_case.disable_revocation_list.()
    :ok
  end

  describe "Basic live page load" do
    test "loads all datasets", %{conn: conn} do
      dataset = TDG.create_dataset(%{})

      event_logs = %{
        title: "title_test",
        timestamp: "timestamp_test",
        source: "source_test",
        description: "description_test",
        ingestion_id: "ingestion_id_test",
        dataset_id: "dataset_id_test"
      }

      allow(Andi.Repo.all(any()), return: [])
      allow(Andi.InputSchemas.EventLogs.get_all_for_dataset_id(any()), return: event_logs)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      heading_text = get_text(html, ".component-title-text")

      assert heading_text == "Event Log"
    end
  end

  #  describe "When form change executes search" do
  #    test "Search Change event triggers redirect and updates search box value", %{conn: conn} do
  #      allow(Andi.Repo.all(any()), return: [])
  #      DatasetHelpers.replace_all_datasets_in_repo([])
  #
  #      {:ok, view, _html} = live(conn, @url_path)
  #
  #      search_text = "Some search"
  #
  #      assert [search_text] ==
  #               view
  #               |> render_change(:search, %{"search-value" => search_text})
  #               |> get_values("input.datasets-index__search-input")
  #
  #      assert_patch(view, encoded(@url_path <> "?search=" <> search_text))
  #    end
  #  end
  #
  #  describe "When form submit executes search" do
  #    test "Search Submit event triggers redirect and updates search box value", %{conn: conn} do
  #      allow(Andi.Repo.all(any()), return: [])
  #      DatasetHelpers.replace_all_datasets_in_repo([])
  #
  #      {:ok, view, _html} = live(conn, @url_path)
  #
  #      search_text = "Some text"
  #
  #      assert [search_text] ==
  #               view
  #               |> render_submit(:search, %{"search-value" => search_text})
  #               |> get_values("input.datasets-index__search-input")
  #
  #      assert_patch(view, encoded(@url_path <> "?search=" <> search_text))
  #    end
  #  end

  defp encoded(url) do
    String.replace(url, " ", "+")
  end
end
