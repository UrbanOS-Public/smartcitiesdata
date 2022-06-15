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

      changes |> Transformation.changeset()
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
end
