defmodule RailStream do
  @moduledoc """
  An abstraction over the `Stream` module to implement Railway Oriented Programming.
  """

  @type value :: term()
  @type reason :: any
  @type element :: {:ok, value} | {:error, reason} | any
  @type original_value :: value
  @type ignored :: any

  @doc """
  Creates a stream that will apply the given `fun` to each non-error tuple on enumeration.

  ## Parameters
  - enum: An `Enumerable` of values, or :ok/:error tuples
  - fun: A function that will be applied to each non-error tuple element of `enum`

  ## Examples

      iex> vals = [1, 2, {:ok, 3}, {:error, 4}]
      iex> RailStream.map(vals, fn val -> val*2 end) |> Enum.to_list()
      [{:ok, 2}, {:ok, 4}, {:ok, 6}, {:error, 4}]
  """

  @spec map(Enumerable.t(), (value -> element)) :: Enumerable.t()
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
  Creates a stream that will reject non-error tuple elements according to the given function on enumeration. Error tuples will be left in place.

  ## Examples

      iex> vals = [1, {:ok, 2}, {:ok, 20}, 30, {:error, 4}]
      iex> RailStream.reject(vals, fn val -> val < 10 end) |> Enum.to_list()
      [{:ok, 20}, 30, {:error, 4}]
  """
  @spec reject(Enumerable.t(), (value -> boolean())) :: Enumerable.t()
  def reject(enum, fun) when is_function(fun, 1) do
    Stream.reject(enum, fn item ->
      case item do
        {:error, _} -> false
        {:ok, value} -> fun.(value)
        value -> fun.(value)
      end
    end)
  end

  @doc """
  Executes the given function for each error tuple in the enum.

  Useful for adding side effects and handling errors to the stream.
  """
  @spec each_error(Enumerable.t(), (reason, original_value -> ignored)) :: Enumerable.t()
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
