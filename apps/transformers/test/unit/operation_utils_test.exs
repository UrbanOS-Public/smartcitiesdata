defmodule Transformers.OperationUtilsTest do
  use ExUnit.Case

  alias Transformers.OperationUtils

  test "allOpsItemsAreFns is provided a list of functions" do
    functions = [fn a -> a end, fn a -> a end, fn a -> a end]

    result = OperationUtils.allOperationsItemsAreFunctions(functions)
    assert result == true
  end

  test "allOpsItemsAreFns is provided a list that contains non functions" do
    functions = [fn a -> a end, "0.0", fn a -> a end]

    result = OperationUtils.allOperationsItemsAreFunctions(functions)
    assert result == false
  end
end
