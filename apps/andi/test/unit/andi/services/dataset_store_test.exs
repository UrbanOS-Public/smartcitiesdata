defmodule Andi.Services.DatasetStoreTest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.DatasetStore
  
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
    
    test "gets dataset event from Brook" do
      %{id: _id} = dataset = TDG.create_dataset(%{})
      
      :meck.expect(Brook.ViewState, :merge, fn :dataset, _id, _dataset -> :ok end)
      
      assert :ok == DatasetStore.update(dataset)
      assert :meck.num_calls(Brook.ViewState, :merge, 3) == 1
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      %{id: _id} = dataset = TDG.create_dataset(%{})
      
      :meck.expect(Brook.ViewState, :merge, fn :dataset, _id, _dataset -> expected_error end)
      
      assert expected_error == DatasetStore.update(dataset)
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
    
    test "gets dataset event from Brook" do
      %{id: id} = expected_dataset = TDG.create_dataset(%{})
      instance_name = Andi.instance_name()
      
      :meck.expect(Brook, :get, fn ^instance_name, :dataset, ^id -> expected_dataset end)
      
      assert expected_dataset == DatasetStore.get(id)
      assert :meck.num_calls(Brook, :get, 3) == 1
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      instance_name = Andi.instance_name()
      
      :meck.expect(Brook, :get, fn ^instance_name, :dataset, "some-id" -> expected_error end)
      
      assert expected_error == DatasetStore.get("some-id")
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
      dataset1 = TDG.create_dataset(%{})
      dataset2 = TDG.create_dataset(%{})
      expected_datasets = {:ok, [dataset1, dataset2]}
      instance_name = Andi.instance_name()
      
      :meck.expect(Brook, :get_all_values, fn ^instance_name, :dataset -> expected_datasets end)
      
      assert expected_datasets == DatasetStore.get_all()
      assert :meck.num_calls(Brook, :get_all_values, 2) == 1
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      instance_name = Andi.instance_name()
      
      :meck.expect(Brook, :get_all_values, fn ^instance_name, :dataset -> expected_error end)
      
      assert expected_error == DatasetStore.get_all()
      assert :meck.num_calls(Brook, :get_all_values, 2) == 1
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
      
      :meck.expect(Brook, :get_all_values!, fn ^instance_name, :dataset -> expected_error end)
      
      assert expected_error == DatasetStore.get_all!()
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
    
    test "deletes dataset event from Brook" do
      :meck.expect(Brook.ViewState, :delete, fn :dataset, "some-id" -> :ok end)
      
      assert :ok == DatasetStore.delete("some-id")
      assert :meck.num_calls(Brook.ViewState, :delete, 2) == 1
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      
      :meck.expect(Brook.ViewState, :delete, fn :dataset, "some-id" -> expected_error end)
      
      assert expected_error == DatasetStore.delete("some-id")
      assert :meck.num_calls(Brook.ViewState, :delete, 2) == 1
    end
  end
end
