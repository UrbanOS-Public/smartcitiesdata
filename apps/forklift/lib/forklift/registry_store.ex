defmodule RegistryStore do
  alias Forklift.DatasetSchema

  def get_schema(dataset_id) do
    raw_schema(dataset_id)
    |> parse_schema()
  end

  defp raw_schema(dataset_id) do
    %{
      id: dataset_id,
      operational: %{
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
    }
  end

  defp parse_schema(%{id: id, operational: %{schema: schema}}) do
    columns = Enum.map(schema, fn %{name: name, type: type} -> {name, type} end)

    %DatasetSchema{
      id: id,
      columns: columns
    }
  end
end
