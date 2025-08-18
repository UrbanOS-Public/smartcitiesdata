defmodule AndiWeb.IngestionLiveView.TableTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  alias Andi.Schemas.User

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]

  @moduletag timeout: 5000

  @endpoint AndiWeb.Endpoint
  @url_path "/ingestions"
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

  describe "Basic ingestions page load" do
    test "shows \"No Ingestions\" when there are no rows to show", %{conn: conn} do
      :meck.expect(Andi.Repo, :all, fn _ -> [] end)
      
      assert {:ok, _view, html} = live(conn, @url_path)

      assert get_text(html, ".ingestions-table__cell") =~ "No Ingestions"
    end

    test "shows ingestions when there are rows to show and the dataset title is nil", %{conn: conn} do
      :meck.expect(Andi.Repo, :all, fn _ -> [%{submissionStatus: :draft, name: "penny", id: "123"}] end)
      
      assert {:ok, _view, html} = live(conn, @url_path)

      assert get_text(html, ".ingestions-table__cell") =~ "penny"
    end

    test "shows ingestions when there are rows to show and the dataset title not nil", %{conn: conn} do
      :meck.expect(Andi.Repo, :all, fn _ -> [%{submissionStatus: :draft, name: "penny", id: "123", dataset: [%{business: %{dataTitle: "Hazel"}}]}] end)
      
      assert {:ok, _view, html} = live(conn, @url_path)

      assert get_text(html, ".ingestions-table__cell") =~ "penny"
      assert get_text(html, ".ingestions-table__cell") =~ "Hazel"
    end

    test "shows ingestions when there are multiple dataset titles not nil", %{conn: conn} do
      datasets = [
        %{business: %{dataTitle: "Hazel"}},
        %{business: %{dataTitle: "Nut"}}
      ]

      :meck.expect(Andi.Repo, :all, fn _ -> [%{submissionStatus: :draft, name: "penny", id: "123", dataset: datasets}] end)
      
      assert {:ok, _view, html} = live(conn, @url_path)

      assert get_text(html, ".ingestions-table__cell") =~ "penny"
      assert get_text(html, ".ingestions-table__cell") =~ "Hazel, Nut"
    end

    test "reflects a draft ingestion status", %{conn: conn} do
      draft_ingestion = %{submissionStatus: :draft, name: "one", id: "123", dataset: %{business: %{dataTitle: "Hazel"}}}

      :meck.expect(Andi.Repo, :all, fn _ -> [draft_ingestion] end)
      
      assert {:ok, _view, html} = live(conn, @url_path)

      assert get_text(html, ".ingestions-table__cell") =~ "Draft"
    end

    test "reflects a published ingestion status", %{conn: conn} do
      published_ingestion = %{submissionStatus: :published, name: "two", id: "456", dataset: %{business: %{dataTitle: "Theo"}}}

      :meck.expect(Andi.Repo, :all, fn _ -> [published_ingestion] end)
      
      assert {:ok, _view, html} = live(conn, @url_path)

      assert get_text(html, ".ingestions-table__cell") =~ "Published"
    end
  end
end
