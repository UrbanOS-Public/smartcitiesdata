defmodule DiscoveryApiWeb.Utilities.DescribeUtils do
  @moduledoc false

  @valid_types ["integer", "decimal", "double", "float", "boolean", "date", "timestamp"]
  def convert_description(description) do
    Enum.map(description, &convert_column/1)
  end

  defp convert_column(%{"Column Name" => name, "Type" => type}) do
    %{name: name, type: translate_type(type)}
  end

  defp translate_type("bigint"), do: "long"
  defp translate_type("varchar"), do: "string"
  defp translate_type("row" <> _), do: "nested"
  defp translate_type("array" <> _), do: "nested"
  defp translate_type(type) when type in @valid_types, do: type
  defp translate_type(_unhandled_type), do: "string"
end
