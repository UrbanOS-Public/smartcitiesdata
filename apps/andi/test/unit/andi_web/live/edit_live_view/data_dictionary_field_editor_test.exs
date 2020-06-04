defmodule AndiWeb.EditLiveView.DataDictionaryFieldEditorTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Checkov

  import FlokiHelpers,
    only: [
      find_elements: 2,
      get_value: 2,
      get_select: 2,
      get_select_first_option: 2,
      get_attributes: 3
    ]

  @url_path "/datasets/"

  test "type-info input is not displayed when type is neither list, date, nor timestamp", %{conn: conn} do
    dataset = DatasetHelpers.create_dataset(%{technical: %{schema: [%{name: "one", type: "string"}]}})

    DatasetHelpers.add_dataset_to_repo(dataset)

    {:ok, _view, html} = live(conn, @url_path <> dataset.id)

    assert Enum.empty?(find_elements(html, ".data-dictionary-field-editor__item-type"))
    assert Enum.empty?(find_elements(html, ".data-dictionary-field-editor__format"))
  end

  test "item type selector is shown when field type is a list", %{conn: conn} do
    field_id = UUID.uuid4()
    dataset = DatasetHelpers.create_dataset(%{technical: %{schema: [%{id: field_id, name: "one", type: "list"}]}})

    DatasetHelpers.add_dataset_to_repo(dataset)

    {:ok, _, html} = live(conn, @url_path <> dataset.id)

    refute Enum.empty?(find_elements(html, ".data-dictionary-field-editor__item-type"))
  end

  data_test "format input is shown when field type is #{field}", %{conn: conn} do
    field_id = UUID.uuid4()
    dataset = DatasetHelpers.create_dataset(%{technical: %{schema: [%{id: field_id, name: "one", type: field}]}})

    DatasetHelpers.add_dataset_to_repo(dataset)

    {:ok, _, html} = live(conn, @url_path <> dataset.id)

    refute Enum.empty?(find_elements(html, ".data-dictionary-field-editor__format"))

    where([
      field: ["date", "timestamp"]
    ])
  end

  data_test "empty values for #{selector_name} are selected by default", %{conn: conn} do
    dataset = DatasetHelpers.create_dataset(%{technical: %{schema: [], sourceType: "remote"}})

    DatasetHelpers.add_dataset_to_repo(dataset)

    {:ok, _view, html} = live(conn, @url_path <> dataset.id)

    case field_type do
      "select" ->
        assert get_select(html, ".data-dictionary-field-editor__#{selector_name}") == []
        assert get_select_first_option(html, ".data-dictionary-field-editor__#{selector_name}") == {"", []}

      "text" ->
        assert get_value(html, ".data-dictionary-field-editor__#{selector_name}") == nil
    end

    where([
      [:selector_name, :field_type],
      ["name", "text"],
      ["type", "select"],
      ["description", "text"],
      ["pii", "select"],
      ["masked", "select"],
      ["demographic", "select"],
      ["biased", "select"],
      ["rationale", "text"]
    ])
  end

  test "xml selector is disabled when source type is not xml", %{conn: conn} do
    dataset = DatasetHelpers.create_dataset(%{technical: %{sourceFormat: "text/csv"}})
    DatasetHelpers.add_dataset_to_repo(dataset)

    {:ok, _view, html} = live(conn, @url_path <> dataset.id)

    refute Enum.empty?(get_attributes(html, ".data-dictionary-field-editor__selector", "disabled"))
  end

  test "xml selector is enabled when source type is xml", %{conn: conn} do
    dataset = DatasetHelpers.create_dataset(%{technical: %{sourceFormat: "text/xml"}})
    DatasetHelpers.add_dataset_to_repo(dataset)

    {:ok, _view, html} = live(conn, @url_path <> dataset.id)

    assert Enum.empty?(get_attributes(html, ".data-dictionary-field-editor__selector", "disabled"))
  end

  describe "validation" do
    data_test "missing #{field} shows error", %{conn: conn} do
      schema =
        [%{name: "cam", type: "list", item_type: "string", selector: "cam/cam"}]
        |> remove_field_from_schema(field)

      dataset = DatasetHelpers.create_dataset(%{technical: %{sourceFormat: "text/xml", schema: schema}})
      DatasetHelpers.add_dataset_to_repo(dataset)

      {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      refute Enum.empty?(find_elements(html, ".data-dictionary-field-editor__#{class} > .error-msg"))

      where(
        field: [:name, :type, :item_type, :selector],
        class: ["name", "type", "type-info", "selector"]
      )
    end

    test "dataset with no schema does not perform field editor validation", %{conn: conn} do
      dataset = DatasetHelpers.create_dataset(%{technical: %{schema: []}})
      DatasetHelpers.add_dataset_to_repo(dataset)

      {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert Enum.empty?(find_elements(html, "#data-dictionary-field-editor > .error-msg"))
    end
  end

  defp remove_field_from_schema(schema, field_key) do
    schema_head = schema |> hd()

    if field_key in Map.keys(schema_head) do
      schema_head
      |> Map.put(field_key, "")
      |> List.wrap()
    end
  end
end
