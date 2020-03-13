defmodule Providers.Echo do
  def provide("1", %{value: value}) do
    value
  end
end
