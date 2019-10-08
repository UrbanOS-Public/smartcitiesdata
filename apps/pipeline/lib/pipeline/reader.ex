defmodule Pipeline.Reader do
  @moduledoc """
  Behaviour describing how to interact with system edges that produce data.
  """

  @callback init(keyword()) :: :ok | {:error, term()}
  @callback terminate(keyword()) :: :ok | {:error, term()}
end
