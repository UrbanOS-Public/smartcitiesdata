defmodule Andi.InputSchemas.Ingestions.ExtractDateStepTest do
  use ExUnit.Case
  import Checkov

  alias Andi.InputSchemas.Ingestions.ExtractDateStep

  describe "changeset validation" do
    test "fails for invalid format" do
      changes = %{
        format: "invalid format goes here"
      }

      changeset = ExtractDateStep.changeset(ExtractDateStep.get_module(), changes)
        |> ExtractDateStep.validate()

      assert changeset.errors[:format] != nil
    end

    test "allows Timex-parsable formats" do
      changes = %{
        format: "{YYYY}"
      }

      changeset = ExtractDateStep.changeset(ExtractDateStep.get_module(), changes)
        |> ExtractDateStep.validate()

      assert changeset.errors[:format] == nil
    end

    test "deltaTimeValue gets casted to integer" do
      changes = %{
        deltaTimeValue: 53.6
      }

      changeset = ExtractDateStep.changeset(ExtractDateStep.get_module(), changes)
        |> ExtractDateStep.validate()

      deltaTimeValue = Ecto.Changeset.get_field(changeset, :deltaTimeValue)
      assert deltaTimeValue == nil
      assert changeset.errors[:deltaTimeValue] == nil
    end

    test "accepts empty string as nil for deltaTimeValue" do
      changes = %{
        deltaTimeValue: ""
      }

      changeset = ExtractDateStep.changeset(ExtractDateStep.get_module(), changes)
        |> ExtractDateStep.validate()

      assert changeset.errors[:deltaTimeValue] == nil
      assert changeset.changes[:deltaTimeValue] == nil
    end

    data_test "allowing \"#{time_unit}\" as deltaTimeUnit makes its validity #{invalid_time_unit?}" do
      changes = %{deltaTimeUnit: time_unit}

      changeset = ExtractDateStep.changeset(ExtractDateStep.get_module(), changes)
        |> ExtractDateStep.validate()

      assert Keyword.has_key?(changeset.errors, :deltaTimeUnit) == invalid_time_unit?

      where([
        [:time_unit, :invalid_time_unit?],
        ["microseconds", false],
        ["milliseconds", false],
        ["seconds", false],
        ["minutes", false],
        ["hours", false],
        ["days", false],
        ["weeks", false],
        ["months", false],
        ["years", false],
        ["", false],
        ["blah", true],
        ["lkdjfsldjgsl", true]
      ])
    end

    data_test "destination \"#{destination}\" is #{if invalid?, do: "invalid", else: "valid"}" do
      changes = %{destination: destination}

      changeset = ExtractDateStep.changeset(ExtractDateStep.get_module(), changes)
        |> ExtractDateStep.validate()

      assert Keyword.has_key?(changeset.errors, :destination) == invalid?

      where([
        [:destination, :invalid?],
        ["a b c", true],
        ["ab1c", true],
        ["111", true],
        ["a-b", true],
        ["!@#$%^&*()", true],
        ["abc", false],
        ["aBc", false],
        ["aB_c", false]
      ])
    end

    test "if deltaTimeUnit is set, then deltaTimeValue must be set" do
      changes = %{deltaTimeUnit: "days", deltaTimeValue: nil}
      changeset = ExtractDateStep.changeset(ExtractDateStep.get_module(), changes)
        |> ExtractDateStep.validate()

      assert Keyword.has_key?(changeset.errors, :deltaTimeValue)
    end

    test "if deltaTimeValue is set, then deltaTimeUnit must be set" do
      changes = %{deltaTimeValue: 1, deltaTimeUnit: ""}
      changeset = ExtractDateStep.changeset(ExtractDateStep.get_module(), changes)
        |> ExtractDateStep.validate()

      assert Keyword.has_key?(changeset.errors, :deltaTimeUnit)
    end

    test "does not add error if neither deltaTimeValue nor deltaTimeUnit are set" do
      changes = %{deltaTimeValue: "", deltaTimeUnit: nil}
      changeset = ExtractDateStep.changeset(ExtractDateStep.get_module(), changes)
        |> ExtractDateStep.validate()

      refute Keyword.has_key?(changeset.errors, :deltaTimeUnit)
      refute Keyword.has_key?(changeset.errors, :deltaTimeValue)
    end
  end
end
