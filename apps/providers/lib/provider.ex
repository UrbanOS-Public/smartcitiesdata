defmodule Providers.Provider do
  @callback provide(String.t(), map()) :: any()
end
