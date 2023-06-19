defmodule Transformers.ParseUtils do
  def operandsToNumbers(operands, payload) when is_list(operands) do
    parseValues(operands, payload)
  end

  def operandsToNumbers(operands, payload) when is_binary(operands) do
    String.split(operands, [" ", ","], trim: true)
    |> parseValues(payload)
  end

  def operandsToNumbers(_, _) do
    {:error, "Operands must be a list of values or a string representation of a list of values"}
  end

  def parseValues(operands, payload) do
    result =
      Enum.reduce_while(operands, [], fn operand, acc ->
        case parseValue(operand, payload) do
          {:ok, number} -> {:cont, [number | acc]}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case result do
      {:error, reason} -> {:error, reason}
      _ -> {:ok, result |> List.flatten() |> Enum.reverse()}
    end
  end

  def parseValue(value, _) when is_number(value) do
    {:ok, value}
  end

  def parseValue(value, payload) when is_list(value) do
    if Regex.match?(~r/\[\*\]/, value) do
      [base_parent_key, child_key] = String.split(value, "[*].")

      list =
        Enum.reduce(payload, [], fn {key, value}, acc ->
          if String.starts_with?(key, base_parent_key) and String.ends_with?(key, child_key) do
            acc ++ [value]
          else
            acc
          end
        end)

      {:ok, list}
    else
      {:error, nil}
    end
  end

  def parseValue(value, payload) do
    {payloadResult, payloadValue} = parsePayloadValue(value, payload)
    {integerResult, integer} = parseInteger(value)
    {floatResult, float} = parseFloat(value)

    cond do
      payloadResult == :ok -> {:ok, payloadValue}
      integerResult == :ok -> {:ok, integer}
      floatResult == :ok -> {:ok, float}
      true -> {:error, "A given value #{value} cannot be parsed to integer or float, nor is it in the following payload: #{inspect(payload)}}"}
    end
  end

  defp parsePayloadValue(value, payload) do
    case Map.get(payload, value) do
      payloadValue when is_number(payloadValue) -> {:ok, payloadValue}
      _ -> {:error, nil}
    end
  end

  defp parseInteger(prospectiveInteger) do
    case Integer.parse(prospectiveInteger) do
      {integer, remainder} when remainder == "" -> {:ok, integer}
      _ -> {:error, nil}
    end
  end

  defp parseFloat(prospectiveFloat) do
    case Float.parse(prospectiveFloat) do
      {float, remainder} when remainder == "" -> {:ok, float}
      _ -> {:error, nil}
    end
  end
end
