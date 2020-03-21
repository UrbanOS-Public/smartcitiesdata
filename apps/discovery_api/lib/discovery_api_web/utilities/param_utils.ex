defmodule DiscoveryApiWeb.Utilities.ParamUtils do
  @moduledoc """
  Utils for extracting values from parameters
  """

  def extract_int_from_params(params, key, default_value \\ 0) do
    params
    |> Map.get(key, default_value)
    |> convert_int()
  end

  defp convert_int(int) when is_integer(int), do: {:ok, int}

  defp convert_int(string) when is_binary(string) do
    case Integer.parse(string) do
      {valid_int, ""} -> {:ok, valid_int}
      _ -> {:request_error, ~s(Could not parse "#{string}" as a number.)}
    end
  end

  def safely_parse_int(int, default_value \\ 0)
  def safely_parse_int(int, _) when is_number(int), do: int

  def safely_parse_int(int, default_value) do
    case Integer.parse(int) do
      {parsed, _} -> parsed
      _ -> default_value
    end
  end
end
