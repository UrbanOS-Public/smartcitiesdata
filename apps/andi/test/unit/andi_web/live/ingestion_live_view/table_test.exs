defmodule AndiWeb.IngestionLiveView.TableTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  alias Andi.Schemas.User

  import Phoenix.LiveViewTest
  import Mock
  import FlokiHelpers, only: [get_text: 2]

  @endpoint AndiWeb.Endpoint
  @url_path "/ingestions"
  @user UserHelpers.create_user()

  setup_with_mocks([
    {Andi.Repo, [],
     [
       get_by: fn Andi.Schemas.User, _ -> @user end
     ]},
    {User, [],
     [
       get_all: fn -> [@user] end,
       get_by_subject_id: fn _ -> @user end
     ]},
    {Guardian.DB.Token, [], [find_by_claims: fn _ -> nil end]}
  ]) do
    :ok
  end

  describe "Basic ingestions page load" do
    test "shows \"No Ingestions\" when there are no rows to show", %{conn: conn} do
      with_mock(Andi.Repo, all: fn _ -> [] end) do
        assert {:ok, _view, html} = live(conn, @url_path)

        assert get_text(html, ".ingestions-table__cell") =~ "No Ingestions"
      end
    end

    test "shows ingestions when there are rows to show and the dataset title is nil", %{conn: conn} do
      with_mock(Andi.Repo, all: fn _ -> [%{submissionStatus: :draft, name: "penny", id: "123"}] end) do
        assert {:ok, _view, html} = live(conn, @url_path)

        assert get_text(html, ".ingestions-table__cell") =~ "penny"
      end
    end

    test "shows ingestions when there are rows to show and the dataset title not nil", %{conn: conn} do
      with_mock(Andi.Repo,
        all: fn _ -> [%{submissionStatus: :draft, name: "penny", id: "123", dataset: [%{business: %{dataTitle: "Hazel"}}]}] end
      ) do
        assert {:ok, _view, html} = live(conn, @url_path)

        assert get_text(html, ".ingestions-table__cell") =~ "penny"
        assert get_text(html, ".ingestions-table__cell") =~ "Hazel"
      end
    end

    test "shows ingestions when there are multiple dataset titles not nil", %{conn: conn} do
      datasets = [
        %{business: %{dataTitle: "Hazel"}},
        %{business: %{dataTitle: "Nut"}}
      ]

      with_mock(Andi.Repo, all: fn _ -> [%{submissionStatus: :draft, name: "penny", id: "123", dataset: datasets}] end) do
        assert {:ok, _view, html} = live(conn, @url_path)

        assert get_text(html, ".ingestions-table__cell") =~ "penny"
        assert get_text(html, ".ingestions-table__cell") =~ "Hazel, Nut"
      end
    end

    test "reflects a draft ingestion status", %{conn: conn} do
      draft_ingestion = %{submissionStatus: :draft, name: "one", id: "123", dataset: %{business: %{dataTitle: "Hazel"}}}

      with_mock(Andi.Repo, all: fn _ -> [draft_ingestion] end) do
        assert {:ok, _view, html} = live(conn, @url_path)

        assert get_text(html, ".ingestions-table__cell") =~ "Draft"
      end
    end

    test "reflects a published ingestion status", %{conn: conn} do
      published_ingestion = %{submissionStatus: :published, name: "two", id: "456", dataset: %{business: %{dataTitle: "Theo"}}}

      with_mock(Andi.Repo, all: fn _ -> [published_ingestion] end) do
        assert {:ok, _view, html} = live(conn, @url_path)

        assert get_text(html, ".ingestions-table__cell") =~ "Published"
      end
    end
  end
end
