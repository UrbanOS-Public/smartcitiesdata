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

  defp translate_columns(cols, child_of_list \\ false) do
    cols
    |> Enum.map(&translate_column(&1, child_of_list))
    |> Enum.join(", ")
  end

  defp translate_column(col, child_of_list \\ false)

  defp translate_column(%{type: "map"} = col, child_of_list) do
    row_def = translate_columns(col.subSchema)

    if child_of_list do
      ~s|row(#{row_def})|
    else
      ~s|"#{safe_col_name(col.name)}" row(#{row_def})|
    end
  end

  defp translate_column(%{type: "list", itemType: "map"} = col, child_of_list) do
    row_def = translate_columns(col.subSchema)

    if child_of_list do
      ~s|array(row(#{row_def}))|
    else
      ~s|"#{safe_col_name(col.name)}" array(row(#{row_def}))|
    end
  end

  defp translate_column(%{type: "list", itemType: "list"} = col, child_of_list) do
    row_def = translate_columns(col.subSchema, true)

    if child_of_list do
      ~s|array(#{row_def})|
    else
      ~s|"#{safe_col_name(col.name)}" array(#{row_def})|
    end
  end

  defp translate_column(%{type: "list", itemType: type} = col, child_of_list) do
    array_def = translate(type)

    if child_of_list do
      ~s|array(#{array_def})|
    else
      ~s|"#{safe_col_name(col.name)}" array(#{array_def})|
    end
  end

  defp translate_column(col, child_of_list) do
    if child_of_list do
      ~s|#{translate(col.type)}|
    else
      ~s|"#{safe_col_name(col.name)}" #{translate(col.type)}|
    end
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

  defp safe_col_name(col_name) do
    String.replace(col_name, "-", "_")
  end
end
