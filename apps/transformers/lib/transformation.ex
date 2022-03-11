# def no_op(message) -> message
# implementation of a "transformation" interface / pattern?

defmodule Transformation do
  @doc """
  Transforms an incoming message
  """
  @callback transform(payload :: Map.t(), parameters :: Map.t()) ::
              {:ok, Map.t()} | {:error, String.t()}
end
