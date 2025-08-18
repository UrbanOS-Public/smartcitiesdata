defmodule AndiWeb.AccessGroupLiveView.ManageDatasetsModalTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]

  alias Andi.Schemas.User
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.AccessGroups
  alias Andi.InputSchemas.AccessGroup
  alias Andi.InputSchemas.Datasets.Dataset

  @moduletag timeout: 5000
  
  @endpoint AndiWeb.Endpoint
  @url_path "/access-groups"
  @user UserHelpers.create_user()

  setup do
    # Set up :meck for global authentication modules
    global_modules = [Andi.Repo, User, Guardian.DB.Token]
    
    # Clean up any existing mocks first
    Enum.each(global_modules, fn module ->
      try do
        :meck.unload(module)
      catch
        _, _ -> :ok
      end
    end)
    
    # Set up fresh mocks
    Enum.each(global_modules, fn module ->
      try do
        :meck.new(module, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
    end)
    
    # Set up global authentication expectations
    :meck.expect(Andi.Repo, :get_by, fn Andi.Schemas.User, _ -> @user end)
    :meck.expect(User, :get_all, fn -> [@user] end)
    :meck.expect(User, :get_by_subject_id, fn _ -> @user end)
    :meck.expect(Guardian.DB.Token, :find_by_claims, fn _ -> nil end)
    
    on_exit(fn ->
      Enum.each(global_modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)
    end)
    
    []
  end

  describe "Basic dataset search load" do
    test "shows \"No Matching Datasets\" when there are no rows to show", %{conn: conn} do
      access_group_id = UUID.uuid4()
      
      # Set up test-specific mocks
      test_modules = [Andi.InputSchemas.Datasets, AccessGroups]
      
      Enum.each(test_modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
        
        try do
          :meck.new(module, [:passthrough])
        catch
          :error, {:already_started, _} -> :ok
        end
      end)
      
      # Set up specific expectations for this test
      :meck.expect(Andi.InputSchemas.Datasets, :get_all, fn -> [] end)
      :meck.expect(AccessGroups, :update, fn _ -> %AccessGroup{id: UUID.uuid4(), name: "group"} end)
      :meck.expect(AccessGroups, :get, fn _ -> %AccessGroup{id: UUID.uuid4(), name: "group"} end)
      :meck.expect(Andi.Repo, :get, fn Andi.InputSchemas.AccessGroup, _ -> [] end)
      :meck.expect(Andi.Repo, :preload, fn _, _ -> %{datasets: [], users: [], id: access_group_id} end)
      
      _access_group = create_access_group(access_group_id)
      assert {:ok, view, _html} = live(conn, "#{@url_path}/#{access_group_id}")

      manage_datasets_button = find_manage_datasets_button(view)
      render_click(manage_datasets_button)
      
      html = render(view)
      assert get_text(html, ".search-table__cell") =~ "No Matching Datasets"
      
      # Cleanup test-specific mocks
      Enum.each(test_modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)
    end

    test "represents a dataset when one exists", %{conn: conn} do
      access_group_id = UUID.uuid4()
      
      # Set up test-specific mocks
      test_modules = [AccessGroups]
      
      Enum.each(test_modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
        
        try do
          :meck.new(module, [:passthrough])
        catch
          :error, {:already_started, _} -> :ok
        end
      end)
      
      # Set up specific expectations for this test
      :meck.expect(AccessGroups, :update, fn _ -> %AccessGroup{id: UUID.uuid4(), name: "group"} end)
      :meck.expect(AccessGroups, :get, fn _ -> %AccessGroup{id: UUID.uuid4(), name: "group"} end)
      :meck.expect(Andi.Repo, :all, fn _ -> [%Dataset{business: %{dataTitle: "Noodles", orgTitle: "Happy", keywords: ["Soup"]}}] end)
      :meck.expect(Andi.Repo, :get, fn Andi.InputSchemas.AccessGroup, _ -> [] end)
      :meck.expect(Andi.Repo, :preload, fn _, _ -> %{datasets: [], users: [], id: access_group_id} end)
      
      _access_group = create_access_group(access_group_id)
      assert {:ok, view, _html} = live(conn, "#{@url_path}/#{access_group_id}")

      manage_datasets_button = find_manage_datasets_button(view)
      render_click(manage_datasets_button)

      html = render_submit(view, "dataset-search", %{"search-value" => "Noodles"})

      assert get_text(html, ".search-table__cell") =~ "Noodles"
      assert get_text(html, ".search-table__cell") =~ "Happy"
      assert get_text(html, ".search-table__cell") =~ "Soup"
      
      # Cleanup test-specific mocks
      Enum.each(test_modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)
    end

    test "represents multiple datasets", %{conn: conn} do
      access_group_id = UUID.uuid4()
      
      # Set up test-specific mocks
      test_modules = [AccessGroups]
      
      Enum.each(test_modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
        
        try do
          :meck.new(module, [:passthrough])
        catch
          :error, {:already_started, _} -> :ok
        end
      end)
      
      # Set up specific expectations for this test
      :meck.expect(AccessGroups, :update, fn _ -> %AccessGroup{id: UUID.uuid4(), name: "group"} end)
      :meck.expect(AccessGroups, :get, fn _ -> %AccessGroup{id: UUID.uuid4(), name: "group"} end)
      :meck.expect(Andi.Repo, :all, fn _ ->
        [
          %Dataset{business: %{dataTitle: "Noodles", orgTitle: "Happy", keywords: ["Soup"]}},
          %Dataset{business: %{dataTitle: "Flowers", orgTitle: "Gardener", keywords: ["Pretty"]}}
        ]
      end)
      :meck.expect(Andi.Repo, :get, fn Andi.InputSchemas.AccessGroup, _ -> [] end)
      :meck.expect(Andi.Repo, :preload, fn _, _ -> %{datasets: [], users: [], id: access_group_id} end)
      
      _access_group = create_access_group(access_group_id)

      assert {:ok, view, _html} = live(conn, "#{@url_path}/#{access_group_id}")

      manage_datasets_button = find_manage_datasets_button(view)
      render_click(manage_datasets_button)

      html = render_submit(view, "dataset-search", %{"search-value" => "Noodles"})

      assert get_text(html, ".search-table__cell") =~ "Noodles"
      assert get_text(html, ".search-table__cell") =~ "Happy"
      assert get_text(html, ".search-table__cell") =~ "Soup"
      assert get_text(html, ".search-table__cell") =~ "Flowers"
      assert get_text(html, ".search-table__cell") =~ "Gardener"
      assert get_text(html, ".search-table__cell") =~ "Pretty"
      
      # Cleanup test-specific mocks
      Enum.each(test_modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)
    end
  end

  defp create_access_group(uuid) do
    access_group = TDG.create_access_group(%{name: "Smrt Access Group", id: uuid})
    AccessGroups.update(access_group)
    access_group
  end

  defp find_manage_datasets_button(view) do
    element(view, ".btn", "Manage Datasets")
  end
end
