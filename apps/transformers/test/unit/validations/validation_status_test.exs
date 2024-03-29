defmodule Transformers.Validations.ValidationStatusTest do
  use ExUnit.Case

  alias Transformers.Validations.ValidationStatus

  describe("struct") do
    test "defaults to empty map of values" do
      assert %ValidationStatus{}.values == %{}
    end

    test "defaults to empty map of errors" do
      assert %ValidationStatus{}.errors == %{}
    end
  end

  describe("update_value/3") do
    test "adds value to provided status" do
      status = %ValidationStatus{}
      field = "some_key"
      value = "some_value"

      result = ValidationStatus.update_value(status, field, value)

      assert result.values == %{field => value}
    end

    test "overwrites value if one already present" do
      field = "some_key"
      status = %ValidationStatus{values: %{field => "old_value"}}

      result = ValidationStatus.update_value(status, field, "new_value")

      assert result.values == %{"some_key" => "new_value"}
    end
  end

  describe("update_error/3") do
    test "adds error to provided status" do
      status = %ValidationStatus{}
      field = "some_key"
      error = "something awful happened!"

      result = ValidationStatus.add_error(status, field, error)

      assert result.errors == %{field => error}
    end

    test "does not overwrite prior errors" do
      field = "some_key"
      original_error = "something awful happened!"
      status = %ValidationStatus{errors: %{field => original_error}}

      result = ValidationStatus.add_error(status, field, "another bad thing!")

      assert result.errors == %{field => original_error}
    end
  end

  describe("get_value/2") do
    test "return value for field" do
      field = "awesome"
      value = "sauce"
      status = %ValidationStatus{values: %{field => value}}

      result = ValidationStatus.get_value(status, field)

      assert result == value
    end

    test "return nil if no matching field" do
      status = %ValidationStatus{}

      result = ValidationStatus.get_value(status, "something")

      assert result == nil
    end
  end

  describe("error/2") do
    test "return error for field" do
      field = "awesome"
      error = "oh no!"
      status = %ValidationStatus{errors: %{field => error}}

      result = ValidationStatus.get_error(status, field)

      assert result == error
    end

    test "return nil if no matching error" do
      status = %ValidationStatus{}

      result = ValidationStatus.get_error(status, "something")

      assert result == nil
    end
  end

  describe("has_error?/2") do
    test "return true if field has associated error" do
      field = "awesome"
      error = "oh no!"
      status = %ValidationStatus{errors: %{field => error}}

      assert ValidationStatus.has_error?(status, field)
    end

    test "return false if no matching error" do
      status = %ValidationStatus{}

      refute ValidationStatus.get_error(status, "something")
    end
  end

  describe("any_errors?/1") do
    test "return true if any errors" do
      status = %ValidationStatus{errors: %{"bad" => "thing"}}

      assert ValidationStatus.any_errors?(status)
    end

    test "return false if no errors" do
      status = %ValidationStatus{}

      refute ValidationStatus.any_errors?(status)
    end
  end

  describe("ordered_values_or_errors/2") do
    test "returns error map if any errors" do
      {:error, result} =
        %ValidationStatus{}
        |> ValidationStatus.add_error("alpha", "nonsense")
        |> ValidationStatus.ordered_values_or_errors(["alpha"])

      assert result == %{"alpha" => "nonsense"}
    end

    test "returns values in specified order if no errors" do
      {:ok, result} =
        %ValidationStatus{}
        |> ValidationStatus.update_value("three", "C")
        |> ValidationStatus.update_value("one", "A")
        |> ValidationStatus.update_value("four", "D")
        |> ValidationStatus.update_value("two", "B")
        |> ValidationStatus.ordered_values_or_errors(["one", "two", "three", "four"])

      assert result == ["A", "B", "C", "D"]
    end
  end
end
