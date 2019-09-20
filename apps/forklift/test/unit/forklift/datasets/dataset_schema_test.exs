defmodule Forklift.Datasets.DatasetSchemaTest do
  use ExUnit.Case

  alias Forklift.Datasets.DatasetSchema
  alias SmartCity.TestDataGenerator, as: TDG

  describe "from_dataset/1" do
    test "returns dataset schema when given ingest SmartCity Dataset struct" do
      dataset =
        TDG.create_dataset(%{
          id: "123",
          technical: %{
            systemName: "system__name",
            sourceType: "ingest",
            schema: [
              %{
                name: "id",
                type: "int"
              },
              %{
                name: "name",
                type: "string"
              }
            ]
          }
        })

      expected = %DatasetSchema{
        id: "123",
        system_name: "system__name",
        columns: dataset.technical.schema
      }

      assert DatasetSchema.from_dataset(dataset) == expected
    end

    test "returns dataset schema when given streaming SmartCity Dataset struct" do
      dataset =
        TDG.create_dataset(%{
          id: "123",
          technical: %{
            systemName: "system__name",
            sourceType: "stream",
            schema: [
              %{
                name: "id",
                type: "int"
              },
              %{
                name: "name",
                type: "string"
              }
            ]
          }
        })

      expected = %DatasetSchema{
        id: "123",
        system_name: "system__name",
        columns: dataset.technical.schema
      }

      assert DatasetSchema.from_dataset(dataset) == expected
    end

    test "returns invalid schema atom when passed a dataset without a schema" do
      dataset = %SmartCity.Dataset{id: "id", technical: %{systemName: "system__name"}}

      assert DatasetSchema.from_dataset(dataset) == :invalid_schema
    end

    test "ignores remote datasets" do
      dataset =
        %{id: "1", technical: %{sourceType: "remote"}}
        |> TDG.create_dataset()

      assert :invalid_schema == DatasetSchema.from_dataset(dataset)
    end

    test "ignores other datasets" do
      dataset =
        %{id: "1", technical: %{sourceType: "unknowable"}}
        |> TDG.create_dataset()

      assert :invalid_schema == DatasetSchema.from_dataset(dataset)
    end
  end
end
