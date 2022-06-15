defmodule Andi.InputSchemas.Ingestions.TransformationsTest do
  use ExUnit.Case
  use Andi.DataCase

  @moduletag shared_data_connection: true

  alias Andi.InputSchemas.Ingestions.Transformations
  alias Andi.InputSchemas.Ingestions.Transformation
  alias SmartCity.TestDataGenerator, as: TDG

  import SmartCity.TestHelper, only: [eventually: 1]

  describe "get/1" do
    test "returns a saved transformation by id" do
      transformation_id = UUID.uuid4()

      changes = %{
        id: transformation_id,
        name: "sample transformation",
        type: "concatenation",
        parameters: %{
          "sourceFields" => ["other", "name"],
          "separator" => ".",
          "targetField" => "name"
        }
      }

      changes
      |> Transformation.changeset()
      |> Transformations.save()

      assert %{
               id: ^transformation_id,
               type: "concatenation",
               parameters: %{
                 "sourceFields" => ["other", "name"],
                 "separator" => ".",
                 "targetField" => "name"
               }
             } = Transformations.get(transformation_id)
    end
  end

  describe "create/0" do
    test "a new  transformation is created with an id" do
      new_transformation = Transformations.create()
      id = new_transformation.changes.id

      eventually(fn ->
        assert %{id: ^id} = Transformations.get(id)
      end)
    end
  end

  describe "delete/1" do
    test "a transformation can be successfully deleted" do
      new_transformation = Transformations.create()
      id = new_transformation.changes.id

      eventually(fn ->
        assert %{id: ^id} = Transformations.get(id)
      end)

      Transformations.delete(id)

      eventually(fn ->
        assert nil == Transformations.get(id)
      end)
    end
  end

  # todo: get all
  # todo: update

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
end
