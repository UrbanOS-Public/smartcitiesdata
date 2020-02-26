defmodule DiscoveryApiWeb.Utilities.DescribeUtils do
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
  defp translate_type(type), do: type
end
