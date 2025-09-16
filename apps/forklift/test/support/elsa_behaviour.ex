defmodule Forklift.Test.ElsaBehaviour do
  @moduledoc """
  Behaviour for mocking Elsa in tests.
  """
  @callback produce(term(), binary(), term()) :: :ok | {:error, term()}
end
