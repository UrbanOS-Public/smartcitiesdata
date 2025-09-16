defmodule Forklift.Test.DateTimeBehaviour do
  @moduledoc """
  Behaviour for mocking DateTime in tests.
  """
  @callback utc_now() :: DateTime.t()
end
