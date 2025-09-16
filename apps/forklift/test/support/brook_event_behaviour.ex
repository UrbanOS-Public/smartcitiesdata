defmodule Forklift.Test.BrookEventBehaviour do
  @moduledoc """
  Behaviour for mocking Brook.Event in tests.
  """
  @callback send(term(), String.t(), atom(), term()) :: :ok | {:error, term()}
end
