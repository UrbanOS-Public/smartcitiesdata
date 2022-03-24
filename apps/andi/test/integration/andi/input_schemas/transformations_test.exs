defmodule Andi.InputSchemas.TransformationsTest do
  use ExUnit.Case
  use Andi.DataCase

  @moduletag shared_data_connection: true

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.Transformations
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.Ingestion
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.ExtractStep

  describe "all_for_ingestion/1" do
    test "given existing transformations, it returns them" do
      dataset_one = TDG.create_dataset(%{})
      dataset_two = TDG.create_dataset(%{})

      assert {:ok, _} = Datasets.update(dataset_one)
      assert {:ok, _} = Datasets.update(dataset_two)

      ingestion_one =
        TDG.create_ingestion(%{
          targetDataset: dataset_one.id,
          transformations: [
            %{
              type: "concatenation",
              parameters: %{
                "sourceFields" => ["other", "name"],
                "separator" => ".",
                "targetField" => "name"
              }
            },
            %{
              type: "regex_extract",
              parameters: %{
                "sourceField" => "name",
                "targetField" => "firstName",
                "regex" => "^(\\w+)"
              }
            }
          ]
        })

      ingestion_two =
        TDG.create_ingestion(%{
          targetDataset: dataset_two.id,
          transformations: [
            %{
              type: "regex_extract",
              parameters: %{
                "sourceField" => "name",
                "targetField" => "firstName",
                "regex" => "^(\\w+)"
              }
            }
          ]
        })

      assert {:ok, _} = Ingestions.update(ingestion_one)
      assert {:ok, _} = Ingestions.update(ingestion_two)

      ingestion_one_id = ingestion_one.id
      ingestion_two_id = ingestion_two.id

      assert [
               %{
                 type: "concatenation",
                 parameters: %{
                   "sourceFields" => ["other", "name"],
                   "separator" => ".",
                   "targetField" => "name"
                 },
                 ingestion_id: ^ingestion_one_id
               },
               %{
                 type: "regex_extract",
                 parameters: %{
                   "sourceField" => "name",
                   "targetField" => "firstName",
                   "regex" => "^(\\w+)"
                 },
                 ingestion_id: ^ingestion_one_id
               }
             ] = Transformations.all_for_ingestion(ingestion_one_id)
    end
  end

  describe "get/1" do
    test "given an existing transformation, it returns it" do
      dataset = TDG.create_dataset(%{})
      assert {:ok, _} = Datasets.update(dataset)

      ingestion =
        TDG.create_ingestion(%{
          targetDataset: dataset.id,
          transformations: [
            %{
              type: "concatenation",
              parameters: %{
                "sourceFields" => ["other", "name"],
                "separator" => ".",
                "targetField" => "name"
              }
            }
          ]
        })

      {:ok,
       %{id: ingestion_id, targetDataset: target_dataset, extractSteps: [%{id: extract_steps_id} | _], schema: [%{id: schema_id} | _]} =
         andi_ingestion} = Ingestions.update(ingestion)

      assert %{
               type: "concatenation",
               parameters: %{
                 "sourceFields" => ["other", "name"],
                 "separator" => ".",
                 "targetField" => "name"
               },
               ingestion_id: ^ingestion_id
             } = Transformations.get(List.first(andi_ingestion.transformations).id)
    end

    test "given a non-existing transformation, it returns nil" do
      assert nil == Transformations.get(UUID.uuid4())
    end
  end

  describe "create/1" do
    test "creates a new treansformation given valid input" do
      id = UUID.uuid4()

      transformation = %{
        id: id,
        type: "concatenation",
        parameters: %{
          "sourceFields" => ["other", "name"],
          "separator" => ".",
          "targetField" => "name"
        }
      }

      Transformations.create(transformation)

      assert %{
               id: id,
               ingestion_id: nil,
               sequence: _,
               type: "concatenation",
               parameters: %{
                 "sourceFields" => ["other", "name"],
                 "separator" => ".",
                 "targetField" => "name"
               }
             } = Transformations.get(id)
    end
  end

  describe "delete/1" do
    test "given an existing transformation, it deletes it" do
      id = UUID.uuid4()

      transformation = %{
        id: id,
        type: "concatenation",
        parameters: %{
          "sourceFields" => ["other", "name"],
          "separator" => ".",
          "targetField" => "name"
        }
      }

      Transformations.create(transformation)

      assert %{
               id: id,
               ingestion_id: nil,
               sequence: _,
               type: "concatenation",
               parameters: %{
                 "sourceFields" => ["other", "name"],
                 "separator" => ".",
                 "targetField" => "name"
               }
             } = Transformations.get(id)

      assert {:ok, _} = Transformations.delete(id)
      assert Transformations.get(id) == nil
    end
  end

  defp delete_in(data, path) do
    pop_in(data, path) |> elem(1)
  end
end
