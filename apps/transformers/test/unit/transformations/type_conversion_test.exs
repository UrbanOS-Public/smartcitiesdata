defmodule Transformers.TypeConversionTest do
  use ExUnit.Case

  test "when field is nil do nothing" do
    payload = %{"nothing" => nil}
    parameters = %{field: "nothing", sourceType: "integer", targetType: "string"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert payload = result
  end

end
