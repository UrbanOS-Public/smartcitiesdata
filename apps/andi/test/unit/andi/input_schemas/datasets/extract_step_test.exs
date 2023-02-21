defmodule Andi.InputSchemas.Ingestions.ExtractStepTest do
  use ExUnit.Case
  # import Checkov

  alias Andi.InputSchemas.Ingestions.ExtractStep

  test "fails for empty context" do
    changes = %{
      type: "http",
      context: nil
    }

    changeset =
      ExtractStep.changeset(changes)
      |> ExtractStep.validate()

    assert changeset.errors[:context] != nil
  end

  test "fails for invalid type" do
    changes = %{
      type: "blarg"
    }

    changeset =
      ExtractStep.changeset(changes)
      |> ExtractStep.validate()

    assert changeset.errors[:type] != nil
  end

  describe "context validation (http)" do
    test "required http step field" do
      changes = %{
        type: "http",
        context: %{
          url: ""
        }
      }

      changeset =
        ExtractStep.changeset(changes)
        |> ExtractStep.validate()

      assert changeset.errors[:url] != nil
      assert changeset.changes.context != nil
    end

    test "complexly validated http step field" do
      changes = %{
        type: "http",
        context: %{
          body: "this is not valid json"
        }
      }

      changeset =
        ExtractStep.changeset(changes)
        |> ExtractStep.validate()

      assert changeset.errors[:body] != nil
    end

    test "context is intact" do
      changes = %{
        type: "http",
        context: %{
          url: "http://www.example.com"
        }
      }

      changeset =
        ExtractStep.changeset(changes)
        |> ExtractStep.validate()

      assert changeset.errors[:url] == nil
      assert changeset.changes.context.url == "http://www.example.com"
    end
  end

  describe "context validation (date)" do
    test "required date step field" do
      changes = %{
        type: "date",
        context: %{
          format: ""
        }
      }

      changeset =
        ExtractStep.changeset(changes)
        |> ExtractStep.validate()

      assert changeset.errors[:format] != nil
      assert changeset.changes.context != nil
    end
  end
end
