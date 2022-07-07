defmodule Andi.InputSchemas.Ingestions.ExtractHttpStepTest do
  use ExUnit.Case
  import Checkov

  alias AndiWeb.Helpers.FormTools
  alias Andi.InputSchemas.Ingestions.ExtractHttpStep
  alias Andi.InputSchemas.Ingestions.ExtractStep

  describe "body validation" do
    setup do
      changes = %{
        type: "http",
        action: "POST",
        url: "123.com",
        body: "",
        queryParams: %{"x" => "y"},
        headers: %{"api-key" => "to-my-heart"}
      }

      [changes: changes]
    end

    data_test "valid when body is #{inspect(value)}", %{changes: changes} do
      changes = Map.put(changes, :body, value)
      changeset = ExtractHttpStep.changeset(changes)

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
      changeset = ExtractHttpStep.changeset(changes)

      assert changeset.errors[:body] == {"could not parse json", [validation: :format]}

      where([
        [:value],
        ["this is invalid json"],
        ["{\"so is\": this"]
      ])
    end
  end

  test "given a url with at least one invalid query param it marks the dataset as invalid" do
    form_data = %{"url" => "https://source.url.example.com?=oops&a=b"} |> FormTools.adjust_extract_query_params_for_url()

    changeset = ExtractHttpStep.changeset_from_form_data(form_data)

    refute changeset.valid?

    assert {:queryParams, {"has invalid format", [validation: :format]}} in changeset.errors

    assert %{queryParams: [%{key: nil, value: "oops"}, %{key: "a", value: "b"}]} = Ecto.Changeset.apply_changes(changeset)
  end

  data_test "given changes with valid #{field} map, properly casts" do
    changes = %{
      action: "GET",
      headers: [%{key: "barl", value: "biz"}, %{key: "yar", value: "har"}],
      id: "49efff5a-81e6-4735-88a0-836149d61e44",
      queryParams: [%{key: "bar", value: "biz"}, %{key: "blah", value: "dah"}],
      technical_id: "dca31ef3-1d2e-4ae9-8587-4706097c6ebc",
      type: "http",
      url: "test.com"
    }

    changeset = ExtractHttpStep.changeset(changes)

    assert changeset.errors[field] == nil
    refute Enum.empty?(Ecto.Changeset.get_field(changeset, field))

    where(field: [:queryParams, :headers])
  end

  data_test "given changes with invalid #{field} map, properly validates" do
    changes = %{
      action: "GET",
      headers: [%{key: "", value: "biz"}, %{key: nil, value: "har"}],
      id: "49efff5a-81e6-4735-88a0-836149d61e44",
      queryParams: [%{key: nil, value: "biz"}, %{key: "", value: "dah"}],
      technical_id: "dca31ef3-1d2e-4ae9-8587-4706097c6ebc",
      type: "http",
      url: "test.com"
    }

    changeset = ExtractHttpStep.changeset(changes)

    assert changeset.errors[field] != nil

    where(field: [:queryParams, :headers])
  end

  test "changeset from andi extract step properly converts queryParams and headers" do
    andi_extract_step = %ExtractStep{
      type: "http",
      context: %{
        queryParams: [%{key: "key1", value: "value1"}],
        headers: [%{key: "key2", value: "value2"}]
      }
    }

    changeset = ExtractHttpStep.changeset_from_andi_step(andi_extract_step.context)
    changeset_headers = Ecto.Changeset.get_field(changeset, :headers)
    changeset_query_params = Ecto.Changeset.get_field(changeset, :queryParams)

    assert changeset.errors[:queryParams] == nil
    assert changeset.errors[:headers] == nil
    assert [%{key: "key1", value: "value1"}] = changeset_query_params
    assert [%{key: "key2", value: "value2"}] = changeset_headers
  end
end
