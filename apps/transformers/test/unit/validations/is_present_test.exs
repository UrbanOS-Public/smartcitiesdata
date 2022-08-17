defmodule Transformers.Validations.IsPresentTest do
  use ExUnit.Case

  alias Transformers.Validations.IsPresent
  alias Transformers.Validations.ValidationStatus

  test "updates values if field present" do
    field = "yay"
    value = " "
    parameters = %{field => value}
    status = %ValidationStatus{}

    result = IsPresent.check(status, parameters, field)

    assert result == %ValidationStatus{values: %{field => value}}
  end

  test "updates errors if field absent" do
    status = %ValidationStatus{}

    result = IsPresent.check(status, %{}, "gone")

    assert result == %ValidationStatus{errors: %{"gone" => "Missing field"}}
  end
end
