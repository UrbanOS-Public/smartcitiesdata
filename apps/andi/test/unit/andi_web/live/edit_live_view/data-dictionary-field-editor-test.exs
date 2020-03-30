defmodule AndiWeb.EditLiveView.DataDictionaryTreeTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Checkov

  alias Andi.DatasetCache

  alias SmartCity.TestDataGenerator, as: TDG

  import FlokiHelpers,
    only: [
      get_value: 2,
      get_select: 2,
      get_select_first_option: 2,
      get_attributes: 3
    ]

  @url_path "/datasets/"

  setup do
    GenServer.call(DatasetCache, :reset)
  end

  test "item type selector is disabled when field type is not a list", %{conn: conn} do
    dataset = TDG.create_dataset(%{technical: %{schema: [%{name: "one", type: "string"}]}})

    DatasetCache.put(dataset)

    {:ok, _view, html} = live(conn, @url_path <> dataset.id)

    assert get_attributes(html, ".data-dictionary-field-editor__item-type", "disabled") != []
  end

  test "item type selector is enabled when field type is a list", %{conn: conn} do
    dataset = TDG.create_dataset(%{technical: %{schema: [%{name: "one", type: "string"}]}})

    DatasetCache.put(dataset)

    {:ok, view, html} = live(conn, @url_path <> dataset.id)

    assert get_attributes(html, ".data-dictionary-field-editor__item-type", "disabled") != []

    dataset_map = EditorHelpers.dataset_to_form_data(dataset) |> Map.put(:schema, %{"0" => %{"name" => "one", "type" => "list"}})

    html = render_change(view, :validate, %{"form_data" => dataset_map})

    assert get_attributes(html, ".data-dictionary-field-editor__item-type", "disabled") == []
  end

  data_test "empty values for #{selector_name} are selected by default", %{conn: conn} do
    dataset = TDG.create_dataset(%{technical: %{schema: [], sourceType: "remote"}})

    DatasetCache.put(dataset)

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
      ["item-type", "select"],
      ["description", "text"],
      ["pii", "select"],
      ["masked", "select"],
      ["demographic", "select"],
      ["biased", "select"],
      ["rationale", "text"]
    ])
  end
end
