defmodule Forklift.Test.RedixBehaviour do
  @moduledoc """
  Test behaviour for mocking Redis operations.
  """
  @callback command!(any(), any()) :: any()
end
