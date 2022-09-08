defmodule Transformers.Validations.NotBlankTest do
  use ExUnit.Case

  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus

  describe("check/3 for binary") do
    test "if field present return ok with value" do
      field = "something"
      value = "present!"
      parameters = %{field => value}
      status = %ValidationStatus{}

      result = NotBlank.check(status, parameters, field)

      assert result == %ValidationStatus{values: %{field => value}}
    end

    test "if field nil return error" do
      field = "something"
      value = nil
      parameters = %{field => value}
      status = %ValidationStatus{}

      result = NotBlank.check(status, parameters, field)

      assert result == %ValidationStatus{errors: %{field => "Missing or empty field"}}
    end

    test "if field empty string return error" do
      field = "something"
      value = ""
      parameters = %{field => value}
      status = %ValidationStatus{}

      result = NotBlank.check(status, parameters, field)

      assert result == %ValidationStatus{errors: %{field => "Missing or empty field"}}
    end

    test "if field whitespace return error" do
      field = "something"
      value = "    "
      parameters = %{field => value}
      status = %ValidationStatus{}

      result = NotBlank.check(status, parameters, field)

      assert result == %ValidationStatus{errors: %{field => "Missing or empty field"}}
    end

    test "if prior errors for field do nothing" do
      field = "something"
      parameters = %{field => "something"}
      status = %ValidationStatus{errors: %{field => "Invalid field"}}

      result = NotBlank.check(status, parameters, field)

      assert result == status
    end
  end

  describe("check/3 for list") do
    test "if field present return ok with value" do
      field = "something"
      value = ["one", "two", "three"]
      parameters = %{field => value}
      status = %ValidationStatus{}

      result = NotBlank.check(status, parameters, field)

      assert result == %ValidationStatus{values: %{field => value}}
    end

    test "if field nil return error" do
      field = "something"
      value = nil
      parameters = %{field => value}
      status = %ValidationStatus{}

      result = NotBlank.check(status, parameters, field)

      assert result == %ValidationStatus{errors: %{field => "Missing or empty field"}}
    end

    test "if prior errors for field do nothing" do
      field = "something"
      parameters = %{field => ["one", "two", "three"]}
      status = %ValidationStatus{errors: %{field => "Invalid field"}}

      result = NotBlank.check(status, parameters, field)

      assert result == status
    end
  end

  describe("check_nil/3 for nil") do
    test "if field present return ok with value" do
      field = "something"
      value = 5
      parameters = %{field => value}
      status = %ValidationStatus{}

      result = NotBlank.check_nil(status, parameters, field)

      assert result == %ValidationStatus{values: %{field => value}}
    end

    test "if field present return error on nil" do
      field = "something"
      parameters = %{field => nil}
      status = %ValidationStatus{}

      result = NotBlank.check_nil(status, parameters, field)

      assert result.errors == %{field => "Missing or empty field"}
    end
  end

  describe("check/3 for unsupported type") do
    test "add error if value neither string or list" do
      field = "something"
      value = %{"not" => "valid"}
      parameters = %{field => value}
      status = %ValidationStatus{}

      result = NotBlank.check(status, parameters, field)

      assert result.errors == %{field => "Not a string or list"}
    end
  end
end
