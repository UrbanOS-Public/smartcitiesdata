defmodule Destination.FinalTests do
  use ExUnit.Case, async: true

  describe "Destination Protocol Core" do
    test "protocol exists" do
      assert {:module, Destination} == Code.ensure_loaded(Destination)
    end

    test "protocol has functions defined" do
      functions = Destination.__protocol__(:functions)
      assert is_list(functions)
      assert Keyword.has_key?(functions, :start_link)
      assert Keyword.has_key?(functions, :write)
      assert Keyword.has_key?(functions, :stop)
      assert Keyword.has_key?(functions, :delete)
    end
  end

  describe "Context Module" do
    test "context struct creation" do
      context = %Destination.Context{}
      assert %Destination.Context{} = context
    end

    test "context with data" do
      context = %Destination.Context{
        app_name: "test",
        dataset_id: "dataset_123",
        subset_id: "subset_456"
      }
      assert context.app_name == "test"
    end
  end

  describe "Mock Implementation" do
    test "mock destination exists" do
      {:module, _} = Code.ensure_loaded(MockDestination)
      true
    end

    test "mock destination struct" do
      mock = %MockDestination{}
      assert %MockDestination{} = mock
    end
  end
end