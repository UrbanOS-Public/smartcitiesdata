defmodule AndiWeb.AccessGroupLiveView.TableTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  alias Andi.Schemas.User

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]
  
  @moduletag timeout: 5000
  
  @endpoint AndiWeb.Endpoint
  @url_path "/access-groups"
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

  describe "Basic access groups page load" do
    test "shows \"No Access Groups Found!\" when there are no rows to show", %{conn: conn} do
      # Set up AccessGroups mock for this test
      try do
        :meck.new(Andi.InputSchemas.AccessGroups, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(Andi.InputSchemas.AccessGroups, :get_all, fn -> [] end)
      
      assert {:ok, _view, html} = live(conn, @url_path)

      assert get_text(html, ".access-groups-table__cell") =~ "No Access Groups Found!"
      
      :meck.unload(Andi.InputSchemas.AccessGroups)
    end

    test "represents an Access Group when one exists", %{conn: conn} do
      group_name = "group-one"
      group_id = UUID.uuid4()
      updated_at = DateTime.utc_now()

      # Set up AccessGroups mock for this test
      try do
        :meck.new(Andi.InputSchemas.AccessGroups, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(Andi.InputSchemas.AccessGroups, :get_all, fn -> [%{name: group_name, id: group_id, updated_at: updated_at}] end)
      
      assert {:ok, _view, html} = live(conn, @url_path)

      assert get_text(html, ".access-groups-table__cell") =~ group_name
      
      :meck.unload(Andi.InputSchemas.AccessGroups)
    end

    test "displays 'Modified Date' attribute correctly", %{conn: conn} do
      group_name = "group-one"
      group_id = UUID.uuid4()
      updated_at = DateTime.utc_now()

      # Set up AccessGroups mock for this test
      try do
        :meck.new(Andi.InputSchemas.AccessGroups, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(Andi.InputSchemas.AccessGroups, :get_all, fn -> [%{name: group_name, id: group_id, updated_at: updated_at}] end)
      
      assert {:ok, _view, html} = live(conn, @url_path)

      expected_time_string = Timex.format!(updated_at, "{M}-{D}-{YYYY}")
      assert get_text(html, ".access-groups-table__cell") =~ expected_time_string
      
      :meck.unload(Andi.InputSchemas.AccessGroups)
    end

    test "represents Access Groups when multiple exist", %{conn: conn} do
      group_name = "group-one"
      group_id = UUID.uuid4()
      updated_at = DateTime.utc_now()

      # Set up AccessGroups mock for this test
      try do
        :meck.new(Andi.InputSchemas.AccessGroups, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(Andi.InputSchemas.AccessGroups, :get_all, fn ->
        [%{name: group_name, id: group_id, updated_at: updated_at}, %{name: "group2", id: UUID.uuid4(), updated_at: updated_at}]
      end)
      
      assert {:ok, _view, html} = live(conn, @url_path)

      assert get_text(html, ".access-groups-table__cell") =~ group_name
      assert get_text(html, ".access-groups-table__cell") =~ "group2"
      
      :meck.unload(Andi.InputSchemas.AccessGroups)
    end
  end
end
