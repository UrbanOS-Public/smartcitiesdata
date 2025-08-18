defmodule Andi.Services.IngestionStoreTest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.IngestionStore
  
  @moduletag timeout: 5000

  describe "update/1" do
    setup do
      # Set up :meck for Brook.ViewState
      modules_to_mock = [Brook.ViewState]
      
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
    
    test "gets ingestion event from Brook" do
      %{id: _id} = ingestion = TDG.create_ingestion(%{})
      
      :meck.expect(Brook.ViewState, :merge, fn :ingestion, _id, _ingestion -> :ok end)
      
      assert :ok == IngestionStore.update(ingestion)
      assert :meck.num_calls(Brook.ViewState, :merge, 3) == 1
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      %{id: _id} = ingestion = TDG.create_ingestion(%{})
      
      :meck.expect(Brook.ViewState, :merge, fn :ingestion, _id, _ingestion -> expected_error end)
      
      assert expected_error == IngestionStore.update(ingestion)
      assert :meck.num_calls(Brook.ViewState, :merge, 3) == 1
    end
  end

  describe "get/1" do
    setup do
      # Set up :meck for Brook
      modules_to_mock = [Brook]
      
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
    
    test "gets ingestion event from Brook" do
      id = "ingestion-id"
      expected_ingestion = TDG.create_ingestion(%{id: id})
      instance_name = Andi.instance_name()
      
      :meck.expect(Brook, :get, fn ^instance_name, :ingestion, ^id -> expected_ingestion end)
      
      assert expected_ingestion == IngestionStore.get(expected_ingestion.id)
      assert :meck.num_calls(Brook, :get, 3) == 1
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      instance_name = Andi.instance_name()
      
      :meck.expect(Brook, :get, fn ^instance_name, :ingestion, "some-id" -> expected_error end)
      
      assert expected_error == IngestionStore.get("some-id")
      assert :meck.num_calls(Brook, :get, 3) == 1
    end
  end

  describe "get_all/0" do
    setup do
      # Set up :meck for Brook
      modules_to_mock = [Brook]
      
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
    
    test "retrieves all events from Brook" do
      ingestion1 = TDG.create_ingestion(%{})
      ingestion2 = TDG.create_ingestion(%{})
      expected_ingestions = {:ok, [ingestion1, ingestion2]}
      instance_name = Andi.instance_name()
      
      :meck.expect(Brook, :get_all_values!, fn ^instance_name, :ingestion -> expected_ingestions end)
      
      assert expected_ingestions == IngestionStore.get_all()
      assert :meck.num_calls(Brook, :get_all_values!, 2) == 1
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      instance_name = Andi.instance_name()
      
      :meck.expect(Brook, :get_all_values!, fn ^instance_name, :ingestion -> expected_error end)
      
      assert expected_error == IngestionStore.get_all()
      assert :meck.num_calls(Brook, :get_all_values!, 2) == 1
    end
  end

  describe "get_all!/0" do
    setup do
      # Set up :meck for Brook
      modules_to_mock = [Brook]
      
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
    
    test "raises the error returned by brook" do
      expected_error = "bad things"
      instance_name = Andi.instance_name()
      
      :meck.expect(Brook, :get_all_values!, fn ^instance_name, :ingestion -> expected_error end)
      
      assert expected_error == IngestionStore.get_all!()
      assert :meck.num_calls(Brook, :get_all_values!, 2) == 1
    end
  end

  describe "delete/1" do
    setup do
      # Set up :meck for Brook.ViewState
      modules_to_mock = [Brook.ViewState]
      
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
    
    test "deletes ingestion event from Brook" do
      :meck.expect(Brook.ViewState, :delete, fn :ingestion, "some-id" -> :ok end)
      
      assert :ok == IngestionStore.delete("some-id")
      assert :meck.num_calls(Brook.ViewState, :delete, 2) == 1
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      
      :meck.expect(Brook.ViewState, :delete, fn :ingestion, "some-id" -> expected_error end)
      
      assert expected_error == IngestionStore.delete("some-id")
      assert :meck.num_calls(Brook.ViewState, :delete, 2) == 1
    end
  end
end
