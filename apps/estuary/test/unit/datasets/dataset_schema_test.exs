defmodule Estuary.Datasets.DatasetSchemaTest do
  use ExUnit.Caase

  alias Estuary.Datasets.DatasetSchema
  alias SmartCity.TestDataGenerator, as: TDG

  describe "from_dataset/1" do
    test "should return dataset schema when given ingest SmartCity Dataset struct" do
      dataset =
        TDG.create_dataset(%{
          schema: [
            %{
              name: "author",
              type: "string"
            },
            %{
              name: "create_ts",
              type: "bigint"
            },
            %{
              name: "data",
              type: "string"
            },
            %{
              name: "type",
              type: "string"
            }
          ]
        })

      expected = %DatasetSchema{
        columns: dataset.technical.schema
      }

      assert DatasetSchema.from_dataset(dataset) == expected
    end
  end
end
