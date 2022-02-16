# def no_op(message) -> message
# implementation of a "transformation" interface / pattern?

defmodule Transformation do
  @doc """
  Transforms an incoming message
  """
  @callback transform(message :: SmartCity.Data.t(), parameters :: Map.t()) ::
              {:ok, SmartCity.Data.t()} | {:error, String.t()}
end
