defmodule AndiWeb.EditLiveView.DataDictionaryFieldEditorTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Checkov

  alias Andi.InputSchemas.FormTools

  import FlokiHelpers,
    only: [
      get_value: 2,
      get_select: 2,
      get_select_first_option: 2,
      get_attributes: 3
    ]

  @url_path "/datasets/"

  test "item type selector is disabled when field type is not a list", %{conn: conn} do
    dataset = DatasetHelpers.create_dataset(%{technical: %{schema: [%{name: "one", type: "string"}]}})

    DatasetHelpers.add_dataset_to_repo(dataset)

    {:ok, _view, html} = live(conn, @url_path <> dataset.id)

    assert get_attributes(html, ".data-dictionary-field-editor__item-type", "disabled") != []
  end

  test "item type selector is enabled when field type is a list", %{conn: conn} do
    field_id = UUID.uuid4()
    dataset = DatasetHelpers.create_dataset(%{technical: %{schema: [%{id: field_id, name: "one", type: "list"}]}})

    DatasetHelpers.add_dataset_to_repo(dataset)

    {:ok, view, html} = live(conn, @url_path <> dataset.id)

    assert get_attributes(html, ".data-dictionary-field-editor__item-type", "disabled") == []

    dataset_map =
      FormTools.form_data_from_andi_dataset(dataset)
      |> put_in(
        [:technical, :schema],
        %{"0" => %{"id" => field_id, "name" => "one", "type" => "list"}}
      )

    render_change(view, :validate, %{"form_data" => dataset_map})

    assert get_attributes(render(view), ".data-dictionary-field-editor__item-type", "disabled") == []
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
end
