defmodule Raptor.Test.Helper do
  @moduledoc """
  Utility functions for tests
  """
  def wait_for_brook_to_be_ready() do
    Process.sleep(5_000)
  end
end
