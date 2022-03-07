defmodule Transformers.RegexUtils do
  def regex_compile(regex) do
    case Regex.compile(regex) do
      {:ok, regex} ->
        {:ok, regex}

      {:error, {message, index}} ->
        {:error, "Invalid regular expression: #{message} at index #{index}"}
    end
  end
end
