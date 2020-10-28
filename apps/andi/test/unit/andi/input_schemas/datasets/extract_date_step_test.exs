defmodule Andi.InputSchemas.Datasets.ExtractDateStepTest do
  use ExUnit.Case

  alias Andi.InputSchemas.Datasets.ExtractDateStep

  test "fails validation for invalid format" do
    changes = %{
      type: "date",
      format: "invalid format goes here"
    }

    changeset = ExtractDateStep.changeset(changes)

    assert changeset.errors[:format] != nil
  end
end
