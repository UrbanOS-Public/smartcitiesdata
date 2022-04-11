defmodule AndiWeb.EditIngestionLiveView.DataDictionaryFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  alias SmartCity.TestDataGenerator, as: TDG

  import SmartCity.Event, only: [ingestion_update: 0, dataset_update: 0]
  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]
  import Phoenix.LiveViewTest

  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions

  import FlokiHelpers,
    only: [
      get_texts: 2
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

      assert {:ok, _view, html} = live(conn, @url_path <> ingestion.id)

      assert ["one", "two", "three"] == get_texts(html, ".data-dictionary-tree-field__name")

      assert ["string", "integer", "float"] ==
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

      assert {:ok, _view, html} = live(conn, @url_path <> ingestion.id)

      assert ["one", "two", "two-one", "three", "three-one", "three-two", "three-two-one"] ==
               get_texts(html, ".data-dictionary-tree-field__name")

      assert ["two", "three", "three-two"] ==
               get_texts(
                 html,
                 ".data-dictionary-tree__field--expanded .data-dictionary-tree-field__name"
               )

      assert ["two-one", "three-one", "three-two", "three-two-one"] ==
               get_texts(
                 html,
                 ".data-dictionary-tree__sub-dictionary .data-dictionary-tree-field__name"
               )

      assert ["three-two-one"] ==
               get_texts(
                 html,
                 ".data-dictionary-tree__sub-dictionary .data-dictionary-tree__sub-dictionary .data-dictionary-tree-field__name"
               )

      assert ["string", "map", "integer", "list", "float", "map", "string"] ==
               get_texts(html, ".data-dictionary-tree-field__type")
    end
  end

  defp create_ingestion_with_schema(schema) do
    dataset = TDG.create_dataset(%{})
    ingestion = TDG.create_ingestion(%{targetDataset: dataset.id, schema: schema})

    Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
    Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

    eventually(fn ->
      assert Ingestions.get(ingestion.id) != nil
    end)

    ingestion
  end
end
