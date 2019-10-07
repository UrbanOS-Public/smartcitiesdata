defmodule Pipeline.Reader do
  @moduledoc "TODO"
  @callback init(keyword()) :: :ok | {:error, term()}
  @callback terminate(keyword()) :: :ok | {:error, term()}
end
