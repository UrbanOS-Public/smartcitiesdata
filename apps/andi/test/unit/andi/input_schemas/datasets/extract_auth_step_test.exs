defmodule Andi.InputSchemas.Ingestions.ExtractAuthStepTest do
  use ExUnit.Case
  import Checkov

  alias Andi.InputSchemas.Ingestions.ExtractAuthStep
  alias Andi.InputSchemas.Ingestions.ExtractStep
  alias Ecto.Changeset

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

    test "changeset casts correctly", %{changes: changes} do
      changeset = ExtractAuthStep.changeset(ExtractAuthStep.get_module(), changes)

      {_, changeset_headers} = Changeset.fetch_field(changeset, :headers)
      assert changeset_headers = [%{"api-key" => "to-my-heart"}]
      {_, changeset_destination} = Changeset.fetch_field(changeset, :destination)
      assert changeset_destination = "dest"
    end

    data_test "valid when body is #{inspect(value)}", %{changes: changes} do
      changes = Map.put(changes, :body, value)

      changeset =
        ExtractAuthStep.changeset(ExtractAuthStep.get_module(), changes)
        |> ExtractAuthStep.validate()

      assert changeset.errors[:body] == nil

      where([
        [:value],
        [""],
        [nil],
        ["[]"],
        ["[{}]"],
        ["[{\"bob\": 1}]"],
        ["<note><to>bob</to><heading>Reminder</heading></note>"]
      ])
    end

    data_test "invalid when body is #{inspect(value)}", %{changes: changes} do
      changes = Map.put(changes, :body, value)

      changeset =
        ExtractAuthStep.changeset(ExtractAuthStep.get_module(), changes)
        |> ExtractAuthStep.validate()

      assert changeset.errors[:body] == {"could not parse json", [validation: :format]}

      where([
        [:value],
        ["this is invalid json"],
        ["{\"so is\": this"]
      ])
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

      changeset = ExtractAuthStep.changeset(ExtractAuthStep.get_module(), changes)

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

      changeset =
        ExtractAuthStep.changeset(ExtractAuthStep.get_module(), changes)
        |> ExtractAuthStep.validate()

      assert changeset.errors[:headers] != nil
    end

    test "changeset from andi extract step properly converts headers" do
      andi_extract_step_changes = %{
        headers: [%{key: "key2", value: "value2"}]
      }

      changeset =
        ExtractAuthStep.changeset(ExtractAuthStep.get_module(), andi_extract_step_changes)
        |> ExtractAuthStep.validate()

      changeset_headers = Ecto.Changeset.get_field(changeset, :headers)

      assert changeset.errors[:headers] == nil
      assert [%{key: "key2", value: "value2"}] = changeset_headers
    end

    test "changeset requires path fields to not be empty" do
      andi_extract_step_changes_1 = %{
        path: ["", "ldkfjjalsdjg"]
      }

      andi_extract_step_changes_2 = %{
        path: ["lsdjglsdj", nil]
      }

      changeset1 =
        ExtractAuthStep.changeset(ExtractAuthStep.get_module(), andi_extract_step_changes_1)
        |> ExtractAuthStep.validate()

      assert Keyword.has_key?(changeset1.errors, :path)

      changeset2 =
        ExtractAuthStep.changeset(ExtractAuthStep.get_module(), andi_extract_step_changes_2)
        |> ExtractAuthStep.validate()

      assert Keyword.has_key?(changeset2.errors, :path)
    end
  end
end
