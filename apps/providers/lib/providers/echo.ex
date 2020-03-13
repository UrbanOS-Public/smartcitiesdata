defmodule Providers.Echo do
  @moduledoc """
  This provider implementation is intended for testing purposes. Given a `value` opt, it will return it.
  """
  @behaviour Providers.Provider
  def provide("1", %{value: value}) do
    value
  end
end
