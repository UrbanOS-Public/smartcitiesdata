defmodule ProtocolDestination.FinalTest do
  use ExUnit.Case, async: true

  alias Destination.Context

  # Custom mock destination for testing
  defmodule TestDestination do
    defstruct [:name, :status]
  end

  defimpl Destination, for: TestDestination do
    def start_link(destination, context) do
      {:ok, {destination, context}}
    end
    
    def write(destination, _server, messages) do
      {:ok, {destination, messages}}
    end
    
    def stop(destination, _server) do
      {:ok, destination}
    end
    
    def delete(destination) do
      {:ok, destination}
    end
  end

  describe "Destination Protocol Core Tests" do
    test "protocol defines correct functions" do
      functions = Destination.__protocol__(:functions)
      expected_functions = [:delete, :start_link, :stop, :write]
      
      Enum.each(expected_functions, fn fun ->
        assert Keyword.has_key?(functions, fun), "Function #{fun} should be defined in protocol"
      end)
      
      assert length(functions) == 4
    end

    test "protocol callbacks are properly defined" do
      callbacks = Destination.__protocol__(:callbacks)
      assert is_list(callbacks)
      assert length(callbacks) == 4
    end
  end

  describe "Context Creation Tests" do
    test "context struct creation with minimal attributes" do
      context = %Context{dictionary: nil, app_name: nil, dataset_id: nil, subset_id: nil}
      assert %Context{} = context
    end

    test "context struct with full attributes" do
      context = %Context{
        dictionary: %{name: "test"},
        app_name: :test_app,
        dataset_id: "dataset_123", 
        subset_id: "subset_456"
      }
      assert context.dictionary == %{name: "test"}
      assert context.app_name == :test_app
      assert context.dataset_id == "dataset_123"
      assert context.subset_id == "subset_456"
    end

    test "context struct field access" do
      context = %Context{app_name: "my_app"}
      assert context.app_name == "my_app"
      assert context.dictionary == nil
      assert context.dataset_id == nil
      assert context.subset_id == nil
    end
  end

  describe "Protocol Implementation