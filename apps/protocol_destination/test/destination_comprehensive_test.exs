defmodule Destination.ComprehensiveTest do
  use ExUnit.Case, async: true
  
  alias Destination.Context
  
  defmodule TestStruct do
    defstruct [:value, :count]
  end

  defmodule TestDictionary do
    defstruct [:name, :fields]
  end

  defmodule InvalidMockDestination do
    defstruct [:id]
  end

  defmodule ValidMockDestination do
    defstruct [:name, :status]
  end
  
  defimpl Destination, for: ValidMockDestination do
    def start_link(destination, context) do
      {:ok, {destination, context}}
    end
    
    def write(destination, server, messages) do
      {:ok, {destination, messages}}
    end
    
    def stop(destination, server) do
      {:ok, destination}
    end
    
    def delete(destination) do
      {:ok, destination}
    end
  end

  describe "Protocol Implementation Tests" do
    test "protocol functions exist and work correctly" do
      expected_functions =[
               start_link: 2,
               write: 3,
               stop: 2,
               delete: 1
             ] |> Enum.sort()
      actual_functions = Destination.__protocol__(:functions) |> Enum.sort()
      assert actual_functions == expected_functions
    end

    test "ValidMockDestination implements all required functions" do
      destination = %ValidMockDestination{name: "test", status: :active}
      context = %Context{
        dictionary: %TestDictionary{name: "test_dict", fields: []},
        app_name: "test_app",
        dataset_id: "test_dataset", 
        subset_id: "test_subset"
      }
      
      assert {:ok, {^destination, ^context}} = Destination.start_link(destination, context)
      assert {:ok, {^destination, ["msg1", "msg2"]}} = Destination.write(destination, nil, ["msg1", "msg2"])
      assert {:ok, ^destination} = Destination.stop(destination, nil)
      assert {:ok, ^destination} = Destination.delete(destination)
    end
  end

  describe "Error Handling Tests" do
    test "invalid destination implementations return protocol errors" do
      invalid_dest = %InvalidMockDestination{id: 123}
      
      assert_raise Protocol.UndefinedError, fn ->
        Destination.start_link(invalid_dest, nil)
      end
    end
  end
end