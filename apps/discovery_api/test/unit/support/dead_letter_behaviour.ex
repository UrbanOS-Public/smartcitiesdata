defmodule DeadLetterBehaviour do
  @moduledoc false
  # Mox mock behaviour for DeadLetter

  @callback process(list(String.t()), String.t(), any(), String.t(), keyword()) :: :ok | {:error, any()}
end