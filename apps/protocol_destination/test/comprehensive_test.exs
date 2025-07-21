defmodule ProtocolDestination.ComprehensiveTest do
  @moduledoc """
  Comprehensive unit tests for protocol_destination component
  """
  use ExUnit.Case, async: true

  describe "Protocol Basics" do
    test "destination protocol is loaded" do
      assert {:module, Destination} = Code.ensure_loaded(Destination)
    end

    test "protocol defines required functions" do
      functions = Destination.__protocol__(:functions)
      assert Keyword.has_key?(functions, :start_link)
      assert Keyword.has_key?(functions, :write) 
      assert Keyword.has_key?(functions, :stop)
      assert Keyword.has_key?(functions, :delete)
    end

    test "protocol function arities are correct" do
      functions = Destination.__protocol__(:functions)
      assert Keyword.get(functions, :start_link) == 2
      assert Keyword.get(functions, :write) == 3
      assert Keyword.get(functions, :stop) == 2
      assert Keyword.get(functions, :delete) == 1
    end
  end

  describe "Context Module" do
    test "context module is loaded" do
      assert {:module, Destination.Context} = Code.ensure_loaded(Destination.Context)
    end

    test "context struct can be created" do
      context = %Destination.Context{}
      assert %Destination.Context{} = context
    end

    test "context struct has all fields" do
      context = %Destination.Context{}
      assert Map.has_key?(context, :dictionary)
      assert Map.has_key?(context, :app_name)
      assert Map.has_key?(context, :dataset_id)
      assert Map.has_key?(context, :subset_id)
    end

    test "context struct defaults to nil values" do
      context = %Destination.Context{}
      assert context.dictionary == nil
      assert context.app_name == nil
      assert context.dataset_id == nil
      assert context.subset_id == nil
    end

    test "context struct with data" do
      context = %Destination.Context{
        app_name: :test_app,
        dataset_id: "test-dataset",
        subset_id: "test-subset"
      }
      
      assert context.app_name == :test_app
      assert context.dataset_id == "test-dataset"
      assert context.subset_id == "test-subset"
    end
  end

  describe "Context V1 Schema" do
    test "context V1 module is loaded" do
      assert {:module, Destination.Context.V1} = Code.ensure_loaded(Destination.Context.V1)
    end

    test "V1 schema function is defined" do
      functions = Destination.Context.V1.__info__(:functions)
      assert Keyword.has_key?(functions, :s)
    end
  end

  describe "Mock Infrastructure" do
    test "mock destination exists" do
      assert {:module, MockDestination} = Code.ensure_loaded(MockDestination)
    end

    test "mock destination struct" do
      mock = %MockDestination{}
      assert %MockDestination{} = mock
    end

    test "mock destination has implementation module" do
      impl_file = Path.join(__DIR__, "../test/support/mock_destination.exs")
      assert File.exists?(impl_file)
    end
  end

  describe "Edge Cases" do
    test "empty structs work" do
      context = %Destination.Context{}
      assert is_struct(context, Destination.Context)
    end

    test "partial struct creation" do
      context = %Destination.Context{app_name: "partial"}
      assert context.app_name == "partial"
      assert context.dataset_id == nil
    end

    test "struct field access" do
      context = %Destination.Context{dataset_id: "test123"}
      assert context.dataset_id == "test123"
    end
  end

  describe "Module Structure" do
    test "all required files exist" do
      assert File.exists?("lib/destination.ex")
      assert File.exists?("lib/destination/context.ex")
    end

    test "test helper exists" do
      assert File.exists?("test/test_helper.exs")
    end

    test "mock support exists" do
      assert File.exists?("test/support/mock_destination.exs")
    end
  end
end