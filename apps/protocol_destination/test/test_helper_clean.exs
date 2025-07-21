ExUnit.start()

# Simple mock implementations without external dependencies
defmodule DynamicMockDestination do
  defstruct [:name, :config]
  
  def new(name, config \\ []) do
    %__MODULE__{name: name, config: config}
  end
end

# Protocol implementation for tests
if not function_exported?(Destination, :__impl__, 2) or 
   Destination.__impl__(DynamicMockDestination, :for) == Any do
  defimpl Destination, for: DynamicMockDestination do
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
end

# Dictionary mock
if not Code.ensure_loaded?(Dictionary) do
  defmodule Dictionary do
    defstruct [:name]
    
    defmodule Impl do
      defstruct [:name]
    end
  end
end