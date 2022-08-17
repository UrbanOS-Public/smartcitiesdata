defmodule Transformers.ConversionFunctions do
  def pick(source_type, target_type) do
    case {source_type, target_type} do
      {"float", "integer"} -> {:ok, fn value -> Float.round(value) end}
      {"float", "string"} -> {:ok, fn value -> to_string(value) end}
      {"integer", "float"} -> {:ok, fn value -> value / 1 end}
      {"integer", "string"} -> {:ok, fn value -> to_string(value) end}
      {"string", "integer"} -> {:ok, fn value -> String.to_integer(value) end}
      {"string", "float"} -> {:ok, fn value -> String.to_float(value) end}
      _ -> {:error, "Conversion from #{source_type} to #{target_type} is not supported"}
    end
  end
end
