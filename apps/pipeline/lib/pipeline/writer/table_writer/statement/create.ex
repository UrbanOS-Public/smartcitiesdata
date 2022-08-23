defmodule Pipeline.Writer.TableWriter.Statement.Create do
  @moduledoc false

  alias Pipeline.Writer.TableWriter.Statement.FieldTypeError

  @field_type_map %{
    "boolean" => "boolean",
    "date" => "date",
    "double" => "double",
    "float" => "double",
    "integer" => "integer",
    "long" => "bigint",
    "json" => "varchar",
    "string" => "varchar",
    "timestamp" => "timestamp"
  }

  def compose(name, schema) do
    "CREATE TABLE IF NOT EXISTS #{name} (#{translate_columns(schema)})"
  end

  def compose(name, schema, format) do
    "CREATE TABLE IF NOT EXISTS #{name} (#{translate_columns(schema)})  WITH (format = '#{format}')"
  end

  def compose(name, schema, format, partitions) do
    create_statement = compose(name, schema)
    quoted_partitions = partitions |> Enum.map(fn p -> "'#{p}'" end)
    partition = "partitioned_by = ARRAY[" <> (quoted_partitions |> Enum.join(", ")) <> "]"
    format = "format = '#{format}'"

    "#{create_statement} WITH (#{partition}, #{format})"
  end

  defp translate_columns(cols) do
    cols
    |> Enum.map(&translate_column/1)
    |> Enum.join(", ")
  end

  defp translate_column(%{type: "map"} = col) do
    row_def = translate_columns(col.subSchema)
    ~s|"#{col.name}" row(#{row_def})|
  end

  defp translate_column(%{type: "list", itemType: "map"} = col) do
    row_def = translate_columns(col.subSchema)
    ~s|"#{col.name}" array(row(#{row_def}))|
  end

  defp translate_column(%{type: "list", itemType: type} = col) do
    array_def = translate(type)
    ~s|"#{col.name}" array(#{array_def})|
  end

  defp translate_column(col) do
    ~s|"#{col.name}" #{translate(col.type)}|
  end

  defp translate("decimal"), do: "decimal"

  defp translate("decimal" <> precision = type) do
    case Regex.match?(~r|\(\d{1,2},\d{1,2}\)|, precision) do
      true -> type
      false -> raise FieldTypeError, message: "#{type} Type is not supported"
    end
  end

  defp translate(type) do
    @field_type_map
    |> Map.get(type)
    |> case do
      nil -> raise FieldTypeError, message: "#{type} Type is not supported"
      value -> value
    end
  end
end
