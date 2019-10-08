defmodule Pipeline.Writer do
  @moduledoc "TODO"

  @callback init(keyword()) :: :ok | {:error, term()}
  @callback write([term()], keyword()) :: :ok | {:error, term()}
  @callback terminate(keyword()) :: :ok | {:error, term()}
  @callback compact(keyword()) :: :ok | {:error, term()}

  @optional_callbacks compact: 1
end
