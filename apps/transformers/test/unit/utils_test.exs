defmodule Transformers.UtilsTest do
  use ExUnit.Case

  alias Transformers.Utils

  test "allOpsItemsAreFns is provided a list of functions" do
    functions = [fn a -> a end, fn a -> a end, fn a -> a end]

    result = Utils.allOperationsItemsAreFunctions(functions)
    assert result == true
  end

  test "allOpsItemsAreFns is provided a list that contains non functions" do
    functions = [fn a -> a end, "0.0", fn a -> a end]

    result = Utils.allOperationsItemsAreFunctions(functions)
    assert result == false
  end
end
