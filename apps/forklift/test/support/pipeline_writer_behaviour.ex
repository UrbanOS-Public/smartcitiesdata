defmodule Pipeline.Writer do
  @moduledoc """
  Behaviour for the Pipeline.Writer interface.
  """
  @callback write(list(), keyword()) :: :ok | {:error, term()}
  @callback init(keyword()) :: :ok | {:error, term()}
  @callback delete(keyword()) :: :ok | {:error, term()}
end
