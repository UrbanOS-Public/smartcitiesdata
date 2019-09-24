defmodule Pipeline.Reader do
  @moduledoc "TODO"

  @callback init(keyword()) :: :ok | {:error, String.t()}
  # @callback terminate()
end
