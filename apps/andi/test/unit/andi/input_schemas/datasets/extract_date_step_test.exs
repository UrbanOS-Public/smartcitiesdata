defmodule Andi.InputSchemas.Datasets.ExtractDateStepTest do
  use ExUnit.Case
  import Checkov

  alias Andi.InputSchemas.Datasets.ExtractDateStep

  describe "changeset validation" do
    test "fails for invalid format" do
      changes = %{
        format: "invalid format goes here"
      }

      changeset = ExtractDateStep.changeset(changes)

      assert changeset.errors[:format] != nil
    end

    test "allows Timex-parsable formats" do
      changes = %{
        format: "{YYYY}"
      }

      changeset = ExtractDateStep.changeset(changes)

      assert changeset.errors[:format] == nil
    end

    test "requires an positive or negative integer for deltaTimeValue" do
      changes = %{
        deltaTimeValue: 53.6
      }

      changeset = ExtractDateStep.changeset(changes)

      assert changeset.errors[:deltaTimeValue] != nil
    end

    data_test "allowing \"#{time_unit}\" as deltaTimeUnit makes its validity #{invalid_time_unit?}" do
      changes = %{deltaTimeUnit: time_unit}

      changeset = ExtractDateStep.changeset(changes)

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
  end
end
