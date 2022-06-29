defmodule Andi.InputSchemas.Ingestions.ExtractS3StepTest do
  use ExUnit.Case

  alias Andi.InputSchemas.Ingestions.ExtractS3Step
  alias Andi.InputSchemas.Ingestions.ExtractStep

  test "given changes with valid headers map, properly casts" do
    changes = %{
      headers: [%{key: "barl", value: "biz"}, %{key: "yar", value: "har"}],
      id: "49efff5a-81e6-4735-88a0-836149d61e44",
      technical_id: "dca31ef3-1d2e-4ae9-8587-4706097c6ebc",
      type: "s3",
      url: "test.com"
    }

    changeset = ExtractS3Step.changeset(changes)

    assert changeset.errors[:headers] == nil
    refute Enum.empty?(Ecto.Changeset.get_field(changeset, :headers))
  end

  test "given changes with invalid headers map, properly validates" do
    changes = %{
      headers: [%{key: "", value: "biz"}, %{key: nil, value: "har"}],
      id: "49efff5a-81e6-4735-88a0-836149d61e44",
      technical_id: "dca31ef3-1d2e-4ae9-8587-4706097c6ebc",
      type: "s3",
      url: "test.com"
    }

    changeset = ExtractS3Step.changeset(changes)

    assert changeset.errors[:headers] != nil
  end

  test "changeset from andi extract step properly converts headers" do
    andi_extract_step = %ExtractStep{
      type: "s3",
      context: %{
        headers: [%{key: "key2", value: "value2"}]
      }
    }

    changeset = ExtractS3Step.changeset_from_andi_step(andi_extract_step.context)
    changeset_headers = Ecto.Changeset.get_field(changeset, :headers)

    assert changeset.errors[:headers] == nil
    assert [%{key: "key2", value: "value2"}] = changeset_headers
  end
end
