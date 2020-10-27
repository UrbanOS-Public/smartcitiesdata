defmodule Andi.InputSchemas.Datasets.ExtractHttpStepTest do
  use ExUnit.Case
  import Checkov

  alias AndiWeb.Helpers.FormTools
  alias Andi.InputSchemas.Datasets.ExtractHttpStep

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
end
