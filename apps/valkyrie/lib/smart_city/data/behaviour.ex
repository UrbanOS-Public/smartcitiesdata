defmodule SmartCity.Data.Behaviour do
  @callback new(any()) :: {:ok, SmartCity.Data.t()} | {:error, any()}
end
