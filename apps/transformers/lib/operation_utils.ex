defmodule Transformers.OperationUtils do
  def allOperationsItemsAreFunctions(result) do
    Enum.all?(result, fn item -> is_function(item) end)
  end
end
