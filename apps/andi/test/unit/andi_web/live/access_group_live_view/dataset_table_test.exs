defmodule AndiWeb.AccessGroupLiveView.DatasetTableTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]
  
  @moduletag timeout: 10000

  alias Andi.Schemas.User
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.AccessGroups
  alias Andi.InputSchemas.AccessGroup

  @endpoint AndiWeb.Endpoint
  @url_path "/access-groups"
  @user UserHelpers.create_user()

  setup do
    # Enhanced module lifecycle management for complex LiveView testing
    global_modules = [Andi.Repo, User, Guardian.DB.Token]
    
    # Comprehensive cleanup - ensure no stale mocks
    Enum.each(global_modules, fn module ->
      try do
        :meck.unload(module)
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    end)
    
    # Wait for cleanup to complete
    Process.sleep(50)
    
    # Create fresh mocks with enhanced error handling
    Enum.each(global_modules, fn module ->
      try do
        :meck.new(module, [:passthrough, :no_link])
      catch
        :error, {:already_started, _} -> 
          :meck.unload(module)
          :meck.new(module, [:passthrough, :no_link])
        error, reason ->
          IO.puts("Warning: Mock creation error for #{module}: #{inspect({error, reason})}")
          :ok
      end
    end)
    
    # Set up global authentication expectations
    try do
      :meck.expect(Andi.Repo, :get_by, fn Andi.Schemas.User, _ -> @user end)
      :meck.expect(User, :get_all, fn -> [@user] end)
      :meck.expect(User, :get_by_subject_id, fn _ -> @user end)
      :meck.expect(Guardian.DB.Token, :find_by_claims, fn _ -> nil end)
    rescue
      e -> 
        IO.puts("Warning: Failed to set expectations: #{inspect(e)}")
    end
    
    # Enhanced cleanup with proper error handling
    on_exit(fn ->
      Enum.each(global_modules, fn module ->
        try do
          :meck.unload(module)
        rescue
          _ -> :ok
        catch
          _, _ -> :ok
        end
      end)
    end)
    
    []
  end

  describe "Basic associated datasets table load" do
    test "shows \"No Associated Datasets\" when there are no rows to show", %{conn: conn} do
      access_group = TDG.create_access_group(%{})

      # Enhanced per-test mock setup with better error handling
      test_modules = [AccessGroups, Andi.InputSchemas.Datasets]
      
      # Cleanup and setup with retry logic
      Enum.each(test_modules, fn module ->
        try do
          :meck.unload(module)
        rescue
          _ -> :ok
        catch
          _, _ -> :ok
        end
        
        Process.sleep(10)  # Brief pause for cleanup
        
        try do
          :meck.new(module, [:passthrough, :no_link])
        catch
          :error, {:already_started, _} -> 
            :meck.unload(module)
            Process.sleep(10)
            :meck.new(module, [:passthrough, :no_link])
          error, reason ->
            IO.puts("Warning: Failed to create test mock for #{module}: #{inspect({error, reason})}")
        end
      end)
      
      # Set expectations with error handling
      try do
        :meck.expect(AccessGroups, :update, fn _ -> %AccessGroup{id: access_group.id, name: access_group.name} end)
        :meck.expect(AccessGroups, :get, fn _ -> %AccessGroup{id: access_group.id, name: access_group.name} end)
        :meck.expect(Andi.Repo, :preload, fn _, _ -> %{datasets: [], users: [], id: access_group.id} end)
        :meck.expect(Andi.Repo, :get, fn Andi.InputSchemas.AccessGroup, _ -> [] end)
      rescue
        e -> 
          IO.puts("Warning: Failed to set test expectations: #{inspect(e)}")
      end
      
      assert {:ok, _view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      assert get_text(html, ".access-groups-sub-table__cell") =~ "No Associated Datasets"
      
      # Enhanced cleanup
      Enum.each(test_modules, fn module ->
        try do
          :meck.unload(module)
        rescue
          _ -> :ok
        catch
          _, _ -> :ok
        end
      end)
    end

    test "shows an associated dataset", %{conn: conn} do
      %{id: access_group_id, name: access_group_name} = _access_group = TDG.create_access_group(%{})
      %{id: dataset_id} = dataset = TDG.create_dataset(%{})

      # Enhanced per-test mock setup
      test_modules = [AccessGroups, Andi.InputSchemas.Datasets]
      
      Enum.each(test_modules, fn module ->
        try do
          :meck.unload(module)
        rescue
          _ -> :ok
        catch
          _, _ -> :ok
        end
        Process.sleep(10)
        try do
          :meck.new(module, [:passthrough, :no_link])
        catch
          :error, {:already_started, _} -> 
            :meck.unload(module)
            Process.sleep(10)
            :meck.new(module, [:passthrough, :no_link])
          error, reason ->
            IO.puts("Warning: Failed to create test mock for #{module}: #{inspect({error, reason})}")
        end
      end)
      
      try do
        :meck.expect(AccessGroups, :update, fn _ -> %AccessGroup{id: access_group_id, name: access_group_name} end)
        :meck.expect(AccessGroups, :get, fn _ -> %AccessGroup{id: access_group_id, name: access_group_name} end)
        :meck.expect(Andi.Repo, :preload, fn _, _ -> %{datasets: [%{id: dataset_id}], users: [], id: access_group_id} end)
        :meck.expect(Andi.Repo, :get, fn Andi.InputSchemas.AccessGroup, _ -> [] end)
        :meck.expect(Andi.InputSchemas.Datasets, :get, fn ^dataset_id -> dataset end)
      rescue
        e -> IO.puts("Warning: Failed to set expectations: #{inspect(e)}")
      end
      
      assert {:ok, _view, html} = live(conn, "#{@url_path}/#{access_group_id}")

      assert get_text(html, ".access-groups-sub-table__cell") =~ dataset.business.dataTitle
      
      Enum.each(test_modules, fn module ->
        try do
          :meck.unload(module)
        rescue
          _ -> :ok
        catch
          _, _ -> :ok
        end
      end)
    end

    test "shows multiple associated datasets", %{conn: conn} do
      %{id: access_group_id, name: access_group_name} = _access_group = TDG.create_access_group(%{})
      %{id: dataset_1_id} = dataset_1 = TDG.create_dataset(%{})
      %{id: dataset_2_id} = dataset_2 = TDG.create_dataset(%{})

      # Enhanced per-test mock setup
      test_modules = [AccessGroups, Andi.InputSchemas.Datasets]
      
      Enum.each(test_modules, fn module ->
        try do
          :meck.unload(module)
        rescue
          _ -> :ok
        catch
          _, _ -> :ok
        end
        Process.sleep(10)
        try do
          :meck.new(module, [:passthrough, :no_link])
        catch
          :error, {:already_started, _} -> 
            :meck.unload(module)
            Process.sleep(10)
            :meck.new(module, [:passthrough, :no_link])
          error, reason ->
            IO.puts("Warning: Failed to create test mock for #{module}: #{inspect({error, reason})}")
        end
      end)
      
      try do
        :meck.expect(AccessGroups, :update, fn _ -> %AccessGroup{id: access_group_id, name: access_group_name} end)
        :meck.expect(AccessGroups, :get, fn _ -> %AccessGroup{id: access_group_id, name: access_group_name} end)
        :meck.expect(Andi.Repo, :preload, fn _, _ -> %{datasets: [%{id: dataset_1_id}, %{id: dataset_2_id}], users: [], id: access_group_id} end)
        :meck.expect(Andi.Repo, :get, fn Andi.InputSchemas.AccessGroup, _ -> [] end)
        :meck.expect(Andi.InputSchemas.Datasets, :get, fn
          ^dataset_1_id -> dataset_1
          ^dataset_2_id -> dataset_2
        end)
      rescue
        e -> IO.puts("Warning: Failed to set expectations: #{inspect(e)}")
      end
      
      assert {:ok, _view, html} = live(conn, "#{@url_path}/#{access_group_id}")

      assert get_text(html, ".access-groups-sub-table__data-title-cell") =~ dataset_1.business.dataTitle
      assert get_text(html, ".access-groups-sub-table__data-title-cell") =~ dataset_2.business.dataTitle
      
      Enum.each(test_modules, fn module ->
        try do
          :meck.unload(module)
        rescue
          _ -> :ok
        catch
          _, _ -> :ok
        end
      end)
    end

    test "shows a remove button for each dataset", %{conn: conn} do
      %{id: access_group_id, name: access_group_name} = _access_group = TDG.create_access_group(%{})
      %{id: dataset_1_id} = dataset_1 = TDG.create_dataset(%{})
      %{id: dataset_2_id} = dataset_2 = TDG.create_dataset(%{})

      # Enhanced per-test mock setup
      test_modules = [AccessGroups, Andi.InputSchemas.Datasets]
      
      Enum.each(test_modules, fn module ->
        try do
          :meck.unload(module)
        rescue
          _ -> :ok
        catch
          _, _ -> :ok
        end
        Process.sleep(10)
        try do
          :meck.new(module, [:passthrough, :no_link])
        catch
          :error, {:already_started, _} -> 
            :meck.unload(module)
            Process.sleep(10)
            :meck.new(module, [:passthrough, :no_link])
          error, reason ->
            IO.puts("Warning: Failed to create test mock for #{module}: #{inspect({error, reason})}")
        end
      end)
      
      try do
        :meck.expect(Andi.Repo, :preload, fn _, _ -> %{datasets: [%{id: dataset_1_id}, %{id: dataset_2_id}], users: [], id: access_group_id} end)
        :meck.expect(Andi.Repo, :get, fn Andi.InputSchemas.AccessGroup, _ -> [] end)
        :meck.expect(Andi.InputSchemas.Datasets, :get, fn
          ^dataset_1_id -> dataset_1
          ^dataset_2_id -> dataset_2
        end)
        :meck.expect(AccessGroups, :update, fn _ -> %AccessGroup{id: access_group_id, name: access_group_name} end)
        :meck.expect(AccessGroups, :get, fn _ -> %AccessGroup{id: access_group_id, name: access_group_name} end)
      rescue
        e -> IO.puts("Warning: Failed to set expectations: #{inspect(e)}")
      end
      
      assert {:ok, _view, html} = live(conn, "#{@url_path}/#{access_group_id}")
      text = get_text(html, ".access-groups-sub-table__cell")
      results = Regex.scan(~r/Remove/, text)

      assert length(results) == 2
      
      Enum.each(test_modules, fn module ->
        try do
          :meck.unload(module)
        rescue
          _ -> :ok
        catch
          _, _ -> :ok
        end
      end)
    end
  end
end
