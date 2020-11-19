defmodule Andi.InputSchemas.Datasets.ExtractAuthStepTest do
  use ExUnit.Case
  import Checkov

  alias AndiWeb.Helpers.FormTools
  alias Andi.InputSchemas.Datasets.ExtractAuthStep
  alias Andi.InputSchemas.Datasets.ExtractStep

  describe "body validation" do
    setup do
      changes = %{
        type: "auth",
        url: "123.com",
        body: "",
        headers: %{"api-key" => "to-my-heart"},
        destination: "dest",
        path: ["cam", "tim"],
        cacheTtl: 5
      }

      [changes: changes]
    end

    data_test "valid when body is #{inspect(value)}", %{changes: changes} do
      changes = Map.put(changes, :body, value)
      changeset = ExtractAuthStep.changeset(changes)

      assert changeset.errors[:body] == nil

      where([
        [:value],
        [""],
        [nil],
        ["[]"],
        ["[{}]"],
        ["[{\"bob\": 1}]"]
      ])
    end

    data_test "invalid when body is #{inspect(value)}", %{changes: changes} do
      changes = Map.put(changes, :body, value)
      changeset = ExtractAuthStep.changeset(changes)

      assert changeset.errors[:body] == {"could not parse json", [validation: :format]}

      where([
        [:value],
        ["this is invalid json"],
        ["{\"so is\": this"]
      ])
    end
  end

  test "given changes with valid headers map, properly casts" do
    changes = %{
      headers: [%{key: "barl", value: "biz"}, %{key: "yar", value: "har"}],
      id: "49efff5a-81e6-4735-88a0-836149d61e44",
      technical_id: "dca31ef3-1d2e-4ae9-8587-4706097c6ebc",
      type: "auth",
      url: "test.com",
      destination: "dest",
      path: ["cam", "tim"],
      cacheTtl: 5
    }

    changeset = ExtractAuthStep.changeset(changes)

    assert changeset.errors[:headers] == nil
    refute Enum.empty?(Ecto.Changeset.get_field(changeset, :headers))
  end

  test "given changes with invalid headers map, properly validates" do
    changes = %{
      headers: [%{key: "", value: "biz"}, %{key: nil, value: "har"}],
      id: "49efff5a-81e6-4735-88a0-836149d61e44",
      technical_id: "dca31ef3-1d2e-4ae9-8587-4706097c6ebc",
      type: "auth",
      url: "test.com",
      destination: "dest",
      path: ["cam", "tim"],
      cacheTtl: 5
    }

    changeset = ExtractAuthStep.changeset(changes)

    assert changeset.errors[:headers] != nil
  end

  test "changeset from andi extract step properly converts headers" do
    andi_extract_step = %ExtractStep{
      type: "auth",
      context: %{
        headers: [%{key: "key2", value: "value2"}]
      }
    }

    changeset = ExtractAuthStep.changeset_from_andi_step(andi_extract_step.context)
    changeset_headers = Ecto.Changeset.get_field(changeset, :headers)

    assert changeset.errors[:headers] == nil
    assert [%{key: "key2", value: "value2"}] = changeset_headers
  end

  test "changeset requires path fields to not be empty" do
    andi_extract_step1 = %ExtractStep{
      type: "auth",
      context: %{
        path: ["", "ldkfjjalsdjg"]
      }
    }

    andi_extract_step2 = %ExtractStep{
      type: "auth",
      context: %{
        path: ["lsdjglsdj", nil]
      }
    }

    changeset1 = ExtractAuthStep.changeset_from_andi_step(andi_extract_step1.context)
    assert Keyword.has_key?(changeset1.errors, :path)

    changeset2 = ExtractAuthStep.changeset_from_andi_step(andi_extract_step2.context)
    assert Keyword.has_key?(changeset2.errors, :path)
  end
end
