defmodule Forklift.Test.ElsaStub do
  @moduledoc """
  Stub implementation of ElsaBehaviour for testing.
  """
  @behaviour Forklift.Test.ElsaBehaviour

  @impl Forklift.Test.ElsaBehaviour
  def produce(_endpoints, _topic, _messages) do
    :ok
  end
end