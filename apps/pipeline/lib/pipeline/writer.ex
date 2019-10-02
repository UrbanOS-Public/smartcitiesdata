defmodule Pipeline.Writer do
  @moduledoc "TODO"
  @callback init(keyword()) :: :ok | {:error, term()}
  @callback write([term()], keyword()) :: :ok | {:error, term()}
end
