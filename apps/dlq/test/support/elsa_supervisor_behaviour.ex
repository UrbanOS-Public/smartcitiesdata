defmodule Dlq.Test.ElsaSupervisorBehaviour do
  @moduledoc """
  Behaviour for mocking Elsa.Supervisor functions in tests.
  """
  @callback start_link(keyword()) :: {:ok, pid()} | {:error, term()}
end