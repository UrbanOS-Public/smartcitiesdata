defmodule RailStream do
  @moduledoc """
  An abstraction over the `Stream` module to implement Railway Oriented Programming.
  Jake's brilliant idea!
  """

  @doc """

  """
  def map(enum, fun) when is_function(fun, 1) do
    Stream.map(enum, fn item ->
      case item do
        {:error, _} = error -> error
        {:ok, value} -> handle_result(value, fun.(value))
        value -> handle_result(value, fun.(value))
      end
    end)
  end

  @doc """

  """
  def reject(enum, fun) when is_function(fun, 1) do
    Stream.reject(enum, fn item ->
      case item do
        {:error, _} = error -> false
        {:ok, value} -> fun.(value)
        value -> fun.(value)
      end
    end)
  end

  @doc """

  """
  def each_error(enum, fun) when is_function(fun, 2) do
    Stream.each(enum, fn item ->
      case item do
        {:error, %{reason: reason, original: original}} -> fun.(reason, original)
        _ -> nil
      end
    end)
  end

  defp handle_result(_original_item, {:ok, result}), do: {:ok, result}
  defp handle_result(original_item, {:error, reason}), do: {:error, %{reason: reason, original: original_item}}
  defp handle_result(_original_item, result), do: {:ok, result}
end
