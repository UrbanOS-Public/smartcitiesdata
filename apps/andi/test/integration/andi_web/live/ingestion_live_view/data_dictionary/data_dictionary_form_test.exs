defmodule AndiWeb.IngestionLiveView.DataDictionaryFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  import SmartCity.Event, only: [ingestion_update: 0, dataset_update: 0]
  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]
  import Phoenix.LiveViewTest
  import Checkov

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.DataDictionaryFields
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.InputConverter
  alias AndiWeb.Helpers.FormTools
  alias AndiWeb.InputSchemas.IngestionMetadataFormSchema

  import FlokiHelpers,
    only: [
      get_attributes: 3,
      get_value: 2,
      get_select: 2,
      get_all_select_options: 2,
      get_select_first_option: 2,
      get_text: 2,
      get_texts: 2,
      find_elements: 2
    ]

  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()

  @url_path "/ingestions/"

  describe "data_dictionary_tree_view" do
    test "given a schema with no nesting it displays the three fields in a well-known (BEM) way",
         %{conn: conn} do
      schema = [
        %{
          name: "one",
          type: "string"
        },
        %{
          name: "two",
          type: "integer"
        },
        %{
          name: "three",
          type: "float"
        }
      ]

      ingestion = create_ingestion_with_schema(schema)
      assert {:ok, _view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      assert ["one", "three", "two"] == get_texts(html, ".data-dictionary-tree-field__name")

      assert ["string", "float", "integer"] ==
               get_texts(html, ".data-dictionary-tree-field__type")
    end

    test "given a schema with nesting it displays the three fields in a well-known (BEM) way", %{
      conn: conn
    } do
      schema = [
        %{
          name: "one",
          type: "string"
        },
        %{
          name: "two",
          type: "map",
          subSchema: [
            %{
              name: "two-one",
              type: "integer"
            }
          ]
        },
        %{
          name: "three",
          type: "list",
          itemType: "map",
          subSchema: [
            %{
              name: "three-one",
              type: "float"
            },
            %{
              name: "three-two",
              type: "map",
              subSchema: [
                %{
                  name: "three-two-one",
                  type: "string"
                }
              ]
            }
          ]
        }
      ]

      ingestion = create_ingestion_with_schema(schema)

      assert {:ok, _view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      assert ["one", "three", "three-one", "three-two", "three-two-one", "two", "two-one"] ==
               get_texts(html, ".data-dictionary-tree-field__name")

      assert ["three", "three-two", "two"] ==
               get_texts(
                 html,
                 ".data-dictionary-tree__field--expanded .data-dictionary-tree-field__name"
               )

      assert ["three-one", "three-two", "three-two-one", "two-one"] ==
               get_texts(
                 html,
                 ".data-dictionary-tree__sub-dictionary .data-dictionary-tree-field__name"
               )

      assert ["three-two-one"] ==
               get_texts(
                 html,
                 ".data-dictionary-tree__sub-dictionary .data-dictionary-tree__sub-dictionary .data-dictionary-tree-field__name"
               )

      assert ["string", "list", "float", "map", "string", "map", "integer"] ==
               get_texts(html, ".data-dictionary-tree-field__type")
    end

    test "generates hidden inputs for fields that are not selected", %{conn: conn} do
      schema = [
        %{
          name: "one",
          type: "list",
          itemType: "map",
          description: "description",
          subSchema: [
            %{
              name: "one-one",
              type: "string"
            }
          ]
        },
        %{
          name: "two",
          type: "map",
          description: "this is a map",
          subSchema: [
            %{
              name: "two-one",
              type: "integer"
            }
          ]
        }
      ]

      ingestion = create_ingestion_with_schema(schema)

      assert {:ok, _view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      assert Enum.empty?(find_elements(html, "input[type='hidden']#data_dictionary_form_schema_schema_0_description"))

      assert Enum.empty?(find_elements(html, "input[type='hidden']#data_dictionary_form_schema_schema_1_description"))
    end

    test "displays help for ingestions with empty schema fields", %{conn: conn} do
      ingestion = create_ingestion_with_schema([])

      assert {:ok, _view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      assert get_text(html, ".data-dictionary-tree__getting-started-help") =~ "add a new field"
    end

    test "does not display help for ingestions with empty subschema fields", %{conn: conn} do
      schema = [
        %{
          name: "one",
          type: "map",
          subSchema: []
        }
      ]

      ingestion = create_ingestion_with_schema(schema)

      assert {:ok, _view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      refute get_text(html, ".data-dictionary-tree__getting-started-help") =~ "add a new field"
    end
  end

  describe "add dictionary field modal" do
    setup do
      ingestion =
        create_ingestion_with_schema([
          %{
            name: "one",
            type: "list",
            itemType: "string",
            description: "description",
            subSchema: [
              %{
                name: "one-one",
                type: "string"
              }
            ]
          },
          %{
            name: "two",
            type: "map",
            description: "this is a map",
            subSchema: [
              %{
                name: "two-one",
                type: "integer"
              }
            ]
          }
        ])

      [ingestion: ingestion]
    end

    test "adds field as a sub schema", %{conn: conn, ingestion: ingestion} do
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      assert find_elements(html, ".data-dictionary-add-field-editor--hidden")

      html =
        view
        |> element("#data_dictionary_add-button")
        |> render_click()

      eventually(fn ->
        assert find_elements(html, ".data-dictionary-add-field-editor--visible")
      end)

      assert [
               {"Top Level", _},
               {"one", field_one_id},
               {"two", _}
             ] = get_all_select_options(html, ".data-dictionary-add-field-editor__parent-id select")

      assert {_, ["Top Level"]} =
               get_select_first_option(
                 html,
                 ".data-dictionary-add-field-editor__parent-id select"
               )

      form_data = %{
        "field" => %{
          "name" => "Natty",
          "type" => "string",
          "parent_id" => field_one_id
        }
      }

      view
      |> form("#add_data_dictionary_form", form_data)
      |> render_change()

      render_click(element(view, "#add_data_dictionary_submit_button"))

      eventually(fn ->
        html = render(view)

        assert "Natty" in get_texts(
                 html,
                 "#data_dictionary_tree_one .data-dictionary-tree-field__name"
               )
      end)

      assert find_elements(html, ".data-dictionary-add-field-editor--hidden")
    end

    test "adds field as part of top level schema", %{conn: conn, ingestion: ingestion} do
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      assert find_elements(html, ".data-dictionary-add-field-editor--hidden")

      html =
        view
        |> element("#data_dictionary_add-button")
        |> render_click()

      eventually(fn ->
        assert find_elements(html, ".data-dictionary-add-field-editor--visible")
      end)

      assert [
               {"Top Level", ingestion_id},
               {"one", _},
               {"two", _}
             ] = get_all_select_options(html, ".data-dictionary-add-field-editor__parent-id select")

      assert {_, ["Top Level"]} =
               get_select_first_option(
                 html,
                 ".data-dictionary-add-field-editor__parent-id select"
               )

      form_data = %{
        "field" => %{
          "name" => "Steeeeeeez",
          "type" => "string",
          "parent_id" => ingestion_id
        }
      }

      view
      |> form("#add_data_dictionary_form", form_data)
      |> render_change()

      render_click(element(view, "#add_data_dictionary_submit_button"))

      eventually(fn ->
        html = render(view)

        assert "Steeeeeeez" in get_texts(
                 html,
                 ".data-dictionary-tree-field__name"
               )
      end)

      assert find_elements(html, ".data-dictionary-add-field-editor--hidden")
    end

    test "adding a field to ", %{
      conn: conn,
      ingestion: ingestion
    } do
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      html =
        view
        |> element("#data_dictionary_add-button")
        |> render_click()

      select_options = get_all_select_options(html, ".data-dictionary-add-field-editor__parent-id select")

      expected_options = [
        "Top Level",
        "one",
        "two"
      ]

      Enum.each(select_options, fn {option_name, _} ->
        assert option_name in expected_options
      end)

      form_data = %{
        "field" => %{
          "name" => "Jared",
          "type" => "integer",
          "parent_id" => ingestion.id
        }
      }

      view
      |> form("#add_data_dictionary_form", form_data)
      |> render_change()

      render_click(element(view, "#add_data_dictionary_submit_button"))

      eventually(fn ->
        html = render(view)
        select_options = get_all_select_options(html, ".data-dictionary-add-field-editor__parent-id select")

        assert Enum.any?(select_options, fn {option_name, _} -> option_name == "Jared" end) == false
      end)

      form_data = %{
        "field" => %{
          "name" => "Newer Jared",
          "type" => "list",
          "parent_id" => ingestion.id
        }
      }

      view
      |> form("#add_data_dictionary_form", form_data)
      |> render_change()

      render_click(element(view, "#add_data_dictionary_submit_button"))

      html =
        view
        |> element("#data_dictionary_add-button")
        |> render_click()

      eventually(fn ->
        html = render(view)
        select_options = get_all_select_options(html, ".data-dictionary-add-field-editor__parent-id select")

        assert Enum.any?(select_options, fn {option_name, _} -> option_name == "Newer Jared" end)
      end)
    end

    test "cancels back to modal not being visible", %{conn: conn, ingestion: ingestion} do
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      html =
        view
        |> element("#data_dictionary_add-button")
        |> render_click()

      eventually(fn ->
        assert find_elements(html, ".data-dictionary-add-field-editor--visible")
      end)

      html =
        view
        |> element("#add_data_dictionary_cancel_button")
        |> render_click()

      eventually(fn ->
        assert find_elements(html, ".data-dictionary-add-field-editor--hidden")
      end)
    end
  end

  describe "remove dictionary field modal" do
    setup do
      schema = [
        %{
          name: "one",
          type: "string",
          description: "description"
        },
        %{
          name: "two",
          type: "map",
          description: "this is a map",
          subSchema: [
            %{
              name: "child",
              type: "integer"
            }
          ]
        }
      ]

      [ingestion: create_ingestion_with_schema(schema)]
    end

    test "removes non parent field", %{conn: conn, ingestion: ingestion} do
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      assert find_elements(html, ".data-dictionary-remove-field-editor--hidden")

      view
      |> element(".data-dictionary-tree-field__text", "one")
      |> render_click()

      html =
        view
        |> element("#data_dictionary_remove-button")
        |> render_click()

      eventually(fn ->
        assert find_elements(html, ".data-dictionary-remove-field-editor--visible")
      end)

      html =
        view
        |> element("#data_dictionary_remove_submit_button")
        |> render_click()

      eventually(fn ->
        html = render(view)

        assert "one" not in get_texts(
                 html,
                 "#data_dictionary_tree_one .data-dictionary-tree-field__name"
               )
      end)
    end

    test "removes parent field along with its children", %{conn: conn, ingestion: ingestion} do
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      assert find_elements(html, ".data-dictionary-remove-field-editor--hidden")

      view
      |> element(".data-dictionary-tree-field__text", "two")
      |> render_click()

      html =
        view
        |> element("#data_dictionary_remove-button")
        |> render_click()

      assert find_elements(html, ".data-dictionary-remove-field-editor--visible")

      html =
        view
        |> element("#data_dictionary_remove_submit_button")
        |> render_click()

      assert "WARNING! Removing this field will also remove its children. Would you like to continue?" ==
               get_text(html, ".data-dicitionary-remove-field-editor__message")

      view
      |> element("#data_dictionary_remove_submit_button")
      |> render_click()

      eventually(fn ->
        html = render(view)

        assert "two" not in get_texts(
                 html,
                 ".data-dictionary-tree-field__name"
               )

        assert "child" not in get_texts(
                 html,
                 ".data-dictionary-tree-field__name"
               )
      end)
    end

    test "cannot remove field when none is selected", %{conn: conn, ingestion: ingestion} do
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      html =
        view
        |> element("#data_dictionary_remove-button")
        |> render_click()

      assert find_elements(html, ".data-dictionary-remove-field-editor--hidden")
    end
  end

  test "required schema field displays proper error message", %{conn: conn} do
    ingestion = create_ingestion_with_schema([])

    assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

    assert get_text(html, ".data_dictionary__error-message") == "Please add a field to continue"
  end

  describe "default timestamp/date" do
    setup do
      timestamp_schema = [
        %{name: "timestamp_field", type: "timestamp", default: %{provider: "date", version: "1", opts: %{offset_in_days: -1}}}
      ]

      date_schema = [%{name: "date_field", type: "date", default: %{provider: "date", version: "1", opts: %{offset_in_seconds: -1}}}]
      andi_ingestion_with_timestamp = create_ingestion_with_schema(timestamp_schema)
      andi_ingestion_with_date = create_ingestion_with_schema(date_schema)

      [
        andi_ingestion_with_date: andi_ingestion_with_date,
        andi_ingestion_with_timestamp: andi_ingestion_with_timestamp
      ]
    end

    test "replaces provider with nil when use default checkbox is unselected", %{conn: conn} do
      schema = [
        %{
          name: "date_field",
          type: "date",
          default: %{provider: "date", version: "1", opts: %{offset_in_days: -1}}
        }
      ]

      andi_ingestion = create_ingestion_with_schema(schema)

      schema_field_id = andi_ingestion.schema |> hd() |> Map.get(:id)

      {:ok, view, html} = live(conn, "#{@url_path}/#{andi_ingestion.id}")

      view
      |> element(".data-dictionary-tree-field__text", "date_field")
      |> render_click()

      eventually(fn ->
        html = render(view)
        assert ["checked"] = get_attributes(html, "#data_dictionary_field_editor__use-default", "checked")

        assert get_value(html, "#data_dictionary_field_editor__offset_input") == "-1"
      end)

      form_schema = %{
        "schema" => %{
          "0" => %{
            "ingestion_id" => andi_ingestion.id,
            "format" => "{YYYY}",
            "name" => "date_field",
            "type" => "date",
            "bread_crumb" => "date_field",
            "id" => schema_field_id,
            "use_default" => "false"
          }
        }
      }

      html =
        view
        |> form("#data_dictionary_form", form_data: form_schema)
        |> render_change(%{"_target" => ["form"]})

      eventually(fn ->
        html = render(view)

        assert [] = get_attributes(html, "#data_dictionary_field_editor__use-default", "checked")
        assert ["disabled"] = get_attributes(html, "#data_dictionary_field_editor__offset_input", "disabled")
      end)
    end

    test "replaces nil provider with default when use default checkbox is checked", %{conn: conn} do
      schema = [%{name: "date_field", type: "date", use_default: false}]
      andi_ingestion = create_ingestion_with_schema(schema)

      schema_field_id = andi_ingestion.schema |> hd() |> Map.get(:id)

      {:ok, view, html} = live(conn, "#{@url_path}/#{andi_ingestion.id}")

      view
      |> element(".data-dictionary-tree-field__text", "date_field")
      |> render_click()

      eventually(fn ->
        html = render(view)
        assert [] = get_attributes(html, "#data_dictionary_field_editor__use-default", "checked")

        assert ["disabled"] = get_attributes(html, "#data_dictionary_field_editor__offset_input", "disabled")
      end)

      form_schema = %{
        "schema" => %{
          "0" => %{
            "ingestion_id" => andi_ingestion.id,
            "format" => "{YYYY}",
            "name" => "date_field",
            "type" => "date",
            "bread_crumb" => "date_field",
            "id" => schema_field_id,
            "use_default" => "true"
          }
        }
      }

      html =
        view
        |> form("#data_dictionary_form", form_data: form_schema)
        |> render_change(%{"_target" => ["form"]})

      eventually(fn ->
        html = render(view)

        assert ["checked"] = get_attributes(html, "#data_dictionary_field_editor__use-default", "checked")
        assert get_value(html, "#data_dictionary_field_editor__offset_input") == "0"
      end)
    end

    test "generates provision for timestamps", %{
      conn: conn,
      andi_ingestion_with_timestamp: andi_ingestion_with_timestamp
    } do
      schema_field_id = andi_ingestion_with_timestamp.schema |> hd() |> Map.get(:id)

      {:ok, view, html} = live(conn, "#{@url_path}/#{andi_ingestion_with_timestamp.id}")

      view
      |> element(".data-dictionary-tree-field__text", "timestamp_field")
      |> render_click()

      format = "{YYYY}-{0M}-{0D}"
      offset_in_seconds = -1 * 60 * 60 * 24

      form_schema = %{
        "schema" => %{
          "0" => %{
            "ingestion_id" => andi_ingestion_with_timestamp.id,
            "format" => format,
            "name" => "timestamp_field",
            "type" => "timestamp",
            "bread_crumb" => "timestamp_field",
            "id" => schema_field_id,
            "use_default" => "true",
            "default_offset" => offset_in_seconds
          }
        }
      }

      html =
        view
        |> form("#data_dictionary_form", form_data: form_schema)
        |> render_change(%{"_target" => ["form"]})

      eventually(fn ->
        html = render(view)

        assert format == get_value(html, "#data_dictionary_field_editor_format")
        assert "#{offset_in_seconds}" == get_value(html, "#data_dictionary_field_editor__offset_input")
      end)
    end

    test "generates provision for dates", %{
      conn: conn,
      andi_ingestion_with_date: andi_ingestion_with_date
    } do
      schema_field_id = andi_ingestion_with_date.schema |> hd() |> Map.get(:id)

      {:ok, view, html} = live(conn, "#{@url_path}/#{andi_ingestion_with_date.id}")

      view
      |> element(".data-dictionary-tree-field__text", "date_field")
      |> render_click()

      format = "{YYYY}-{0M}-{0D}"
      offset_in_days = -1

      form_schema = %{
        "schema" => %{
          "0" => %{
            "ingestion_id" => andi_ingestion_with_date.id,
            "default_offset" => offset_in_days,
            "use_default" => "true",
            "format" => format,
            "name" => "date_field",
            "type" => "date",
            "bread_crumb" => "date_field",
            "id" => schema_field_id
          }
        }
      }

      html =
        view
        |> form("#data_dictionary_form", form_data: form_schema)
        |> render_change(%{"_target" => ["form"]})

      eventually(fn ->
        html = render(view)

        assert format == get_value(html, "#data_dictionary_field_editor_format")
        assert "#{offset_in_days}" == get_value(html, "#data_dictionary_field_editor__offset_input")
      end)
    end
  end

  describe "schema sample upload" do
    test "is shown when sourceFormat is CSV or JSON", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      ingestion = TDG.create_ingestion(%{sourceFormat: "application/json", targetDataset: dataset.id})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
      html = render(view)

      assert find_elements(html, ".data-dictionary-form__file-upload")
    end

    test "is shown when sourceFormat is TSV", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      ingestion = TDG.create_ingestion(%{sourceFormat: "text/plain", targetDataset: dataset.id})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
      html = render(view)

      assert find_elements(html, ".data-dictionary-form__file-upload")
    end

    test "is hidden when sourceFormat is not CSV, TSV, nor JSON", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      ingestion = TDG.create_ingestion(%{sourceFormat: "application/geo+json", targetDataset: dataset.id})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
      html = render(view)

      assert Enum.empty?(find_elements(html, ".data-dictionary-form__file-upload"))
    end

    test "does not allow file uploads greater than 200MB", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      ingestion = TDG.create_ingestion(%{sourceFormat: "text/csv", targetDataset: dataset.id})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      html = render_hook(view, "file_upload", %{"fileSize" => 200_000_001})

      eventually(fn ->
        html = render(view)

        assert "File size must be less than 200MB" == get_text(html, ".data_dictionary__error-message")
      end)
    end

    test "should throw error when empty csv file is passed", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      ingestion = TDG.create_ingestion(%{sourceFormat: "text/csv", targetDataset: dataset.id})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      csv_sample = ""

      html = render_hook(view, "file_upload", %{"fileSize" => 100, "fileType" => "text/csv", "file" => csv_sample})

      eventually(fn ->
        html = render(view)

        assert "There was a problem interpreting this file" == get_text(html, ".data_dictionary__error-message")
      end)
    end

    data_test "accepts common csv file type #{type}", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      ingestion = TDG.create_ingestion(%{sourceFormat: "text/csv", targetDataset: dataset.id})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      csv_sample = "string,int,float,bool,date\nabc,9,1.5,true,2020-07-22T21:24:40"

      html = render_hook(view, "file_upload", %{"fileSize" => 10, "fileType" => type, "file" => csv_sample})

      eventually(fn ->
        html = render(view)

        assert "" == get_text(html, ".data_dictionary__error-message")
      end)

      where([
        [:type],
        ["text/csv"],
        ["application/vnd.ms-excel"]
      ])
    end

    test "should throw error when empty csv file with `\n` is passed", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      ingestion = TDG.create_ingestion(%{sourceFormat: "text/csv", targetDataset: dataset.id})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      csv_sample = "\n"

      html = render_hook(view, "file_upload", %{"fileSize" => 100, "fileType" => "text/csv", "file" => csv_sample})

      eventually(fn ->
        html = render(view)

        assert "There was a problem interpreting this file" == get_text(html, ".data_dictionary__error-message")
      end)
    end

    test "provides modal when existing schema will be overwritten", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      ingestion = TDG.create_ingestion(%{sourceFormat: "text/csv", targetDataset: dataset.id})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      csv_sample = "CAM\nrules"

      html = render_hook(view, "file_upload", %{"fileSize" => 100, "fileType" => "text/csv", "file" => csv_sample})

      eventually(fn ->
        render(view)

        assert element(view, ".overwrite-schema-modal--visible")
      end)
    end

    test "does not provide modal with no existing schema", %{conn: conn} do
      ingestion = create_ingestion_with_schema([], "text/csv")

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      csv_sample = "CAM\nrules"

      html = render_hook(view, "file_upload", %{"fileSize" => 100, "fileType" => "text/csv", "file" => csv_sample})

      eventually(fn ->
        render(view)

        assert element(view, ".overwrite-schema-modal--hidden")
      end)
    end

    test "parses CSVs with various types", %{conn: conn} do
      ingestion = create_ingestion_with_schema([], "text/csv")

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      csv_sample = "string,int,float,bool,date,timestamp\nabc,9,1.5,true,2020-07-22,2020-07-22T21:24:40"

      render_hook(view, "file_upload", %{"fileSize" => 100, "fileType" => "text/csv", "file" => csv_sample})

      eventually(fn ->
        render(view)

        assert element(view, ".data-dictionary-tree-field__name", "string")
        assert element(view, ".data-dictionary-tree-field__type", "string")
        assert element(view, ".data-dictionary-tree-field__name", "int")
        assert element(view, ".data-dictionary-tree-field__type", "integer")
        assert element(view, ".data-dictionary-tree-field__name", "float")
        assert element(view, ".data-dictionary-tree-field__type", "float")
        assert element(view, ".data-dictionary-tree-field__name", "bool")
        assert element(view, ".data-dictionary-tree-field__type", "boolean")
        assert element(view, ".data-dictionary-tree-field__name", "date")
        assert element(view, ".data-dictionary-tree-field__type", "date")
        assert element(view, ".data-dictionary-tree-field__name", "timestamp")
        assert element(view, ".data-dictionary-tree-field__type", "timestamp")
      end)
    end

    test "parses CSV with valid column names", %{conn: conn} do
      ingestion = create_ingestion_with_schema([], "text/csv")

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      csv_sample =
        "string\r,i&^%$nt,fl\toat,bool---,date as multi word column,timestamp as multi word column\nabc,9,1.5,true,2020-07-22,2020-07-22T21:24:40"

      render_hook(view, "file_upload", %{"fileSize" => 100, "fileType" => "text/csv", "file" => csv_sample})

      eventually(fn ->
        render(view)

        assert element(view, ".data-dictionary-tree-field__name", "string")
        assert element(view, ".data-dictionary-tree-field__type", "string")
        assert element(view, ".data-dictionary-tree-field__name", "int")
        assert element(view, ".data-dictionary-tree-field__type", "integer")
        assert element(view, ".data-dictionary-tree-field__name", "float")
        assert element(view, ".data-dictionary-tree-field__type", "float")
        assert element(view, ".data-dictionary-tree-field__name", "bool")
        assert element(view, ".data-dictionary-tree-field__type", "boolean")
        assert element(view, ".data-dictionary-tree-field__name", "date as multi word column")
        assert element(view, ".data-dictionary-tree-field__type", "date")
        assert element(view, ".data-dictionary-tree-field__name", "timestamp as multi word column")
        assert element(view, ".data-dictionary-tree-field__type", "timestamp")
      end)
    end

    test "handles invalid json", %{conn: conn} do
      ingestion = create_ingestion_with_schema([])
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      json_sample = "header"

      render_hook(view, "file_upload", %{"fileSize" => 100, "fileType" => "application/json", "file" => json_sample})

      eventually(fn ->
        html = render(view)

        assert "There was a problem interpreting this file: \"header\"" == get_text(html, ".data_dictionary__error-message")
      end)
    end

    test "should throw error when empty json file is passed", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      {:ok, _} = Datasets.update(dataset)
      ingestion = TDG.create_ingestion(%{sourceFormat: "application/json", targetDataset: dataset.id})
      {:ok, _} = Ingestions.update(ingestion)
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      json_sample = "[]"

      render_hook(view, "file_upload", %{"fileSize" => 100, "fileType" => "application/json", "file" => json_sample})

      eventually(fn ->
        html = render(view)

        assert "Json file is empty" == get_text(html, ".data_dictionary__error-message")
      end)
    end
  end

  defp create_ingestion_with_schema(schema, source_format \\ "application/json") do
    dataset = TDG.create_dataset(%{})
    ingestion = TDG.create_ingestion(%{targetDataset: dataset.id, schema: schema, sourceFormat: source_format})

    Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
    Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

    eventually(fn ->
      assert Ingestions.get(ingestion.id) != nil
    end)

    Ingestions.get(ingestion.id)
  end

  defp select_source_format(source_format, view) do
    new_source_format = source_format

    form_data = %{
      "sourceFormat" => new_source_format
    }

    metadata_changeset = IngestionMetadataFormSchema.changeset(%IngestionMetadataFormSchema{}, form_data)
    send(view.pid, {:updated_metadata, metadata_changeset})
    render_change(view, "save")
  end
end
