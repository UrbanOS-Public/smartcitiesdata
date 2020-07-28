defmodule Ok do
  @moduledoc """
  Ok provides functions for handling and returning `{:ok, term}` tuples,
  especially within the context of a pipe chain.
  """

  @type ok :: {:ok, term}
  @type error :: {:error, term}
  @type result :: ok | error

  @doc """
  Takes a value and wraps it in an ok tuple.
  """
  @spec ok(value) :: {:ok, value} when value: term
  def ok(value), do: {:ok, value}

  @doc """
  Takes a value (typically an explanatory error reason) and
  wraps it in an error tuple.
  """
  @spec error(reason) :: {:error, reason} when reason: term
  def error(reason), do: {:error, reason}

  @doc """
  Receives an ok tuple and a single-arity function and calls
  the function with the value within the ok tuple as its input.

  Returns a result wrapped in an ok or error tuple.
  """
  @spec map(result, (term -> term | result)) :: result
  def map({:ok, value}, function) when is_function(function, 1) do
    case function.(value) do
      {:ok, _} = ok -> ok
      {:error, _} = error -> error
      x -> {:ok, x}
    end
  end

  def map({:error, _reason} = error, _function), do: error

  @doc """
  Receives an error tuple and a single-arity function and calls the
  function with the reason within the error tuple as its input.

  Returns an error tuple.
  """
  @spec map_if_error(result, (term -> term)) :: result
  def map_if_error({:error, reason}, function) when is_function(function, 1) do
    {:error, function.(reason)}
  end

  def map_if_error({:ok, _} = result, _function), do: result
  def map_if_error(:ok, _function), do: :ok

  @doc """
  Receives an enumerable, an accumulator, and a function and calls
  `Enum.reduce_while/3`. Continues to reduce as long as the reducer function
  returns an ok tuple, or calls halt if any call to the reducer returns
  an error tuple.

  Returns the accumulator as an ok tuple or else returns an error tuple
  with the explanation for the halted execution.
  """
  @spec reduce(
          Enum.t(),
          Enum.acc(),
          (Enum.element(), Enum.acc() -> {:ok, Enum.acc()} | {:error, reason})
        ) :: {:ok, Enum.acc()} | {:error, reason}
        when reason: term
  def reduce(enum, initial, function) do
    Enum.reduce_while(enum, {:ok, initial}, fn item, {:ok, acc} ->
      case function.(item, acc) do
        {:ok, new_acc} -> {:cont, {:ok, new_acc}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Receives an enumerable and a single-arity function and reduces over
  the enumerable, calling the function with each element as its input.

  If all function executions over the enumerable are successful, a single
  `:ok` is returned, else the error tuple explaining where the error occurred
  is returned.
  """
  @spec each(Enum.t(), (Enum.element() -> term | error)) :: :ok | error
  def each(enum, function) when is_function(function, 1) do
    reduce(enum, nil, fn item, acc ->
      case function.(item) do
        {:error, reason} -> {:error, reason}
        _ -> {:ok, acc}
      end
    end)
    |> case do
      {:ok, _} -> :ok
      error -> error
    end
  end

  def each({:error, _} = error), do: error

  @doc """
  Receives an enumerable and a single-arity function and iterates over the
  elements of the enumerable calling the function with each element as its input.

  The result is either a single ok tuple containing the enumerable with the transformed
  elements or an error tuple explaining where the failure occurred.
  """
  @spec transform(Enum.t(), (Enum.element() -> {:ok, Enum.element()} | {:error, reason})) ::
          {:ok, Enum.t()} | {:error, reason}
        when reason: term
  def transform(enum, function) when is_list(enum) and is_function(function, 1) do
    reduce(enum, [], fn item, acc ->
      function.(item)
      |> map(fn result -> [result | acc] end)
    end)
    |> map(&Enum.reverse/1)
  end

  @doc """
  Receives an enumerable and validates that none of the elements is an error tuple.
  """
  @spec all?(Enum.t()) :: boolean
  def all?(enum) do
    not Enum.any?(enum, &match?({:error, _}, &1))
  end
end
