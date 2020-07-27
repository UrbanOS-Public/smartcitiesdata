defmodule Definition.Schema.Type.LowercaseTest do
  use ExUnit.Case
  import Checkov
  import Norm

  alias Definition.Schema.Type.Lowercase

  data_test "will validate and coerce binaries to lower case" do
    assert output == Norm.conform(input, %Lowercase{})

    where [
      [:input, :output],
      ["hello", {:ok, "hello"}],
      ["Hello", {:ok, "hello"}],
      [1, {:error, [%{input: 1, path: [], spec: "is not a binary"}]}]
    ]
  end

  test "will work in maps" do
    data = %{name: "Joe", age: 21}
    schema = schema(%{name: %Lowercase{}, age: spec(&is_integer/1)})
    assert {:ok, %{name: "joe", age: 21}} == Norm.conform(data, schema)
  end
end
