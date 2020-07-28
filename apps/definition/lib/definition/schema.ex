defmodule Definition.Schema do
  @moduledoc """
  Defines a behaviour for for returning a schema
  compatible with the Norm library and implements
  a `__using__/1` macro for including the necessary
  behaviour declaration and base imports.
  """

  @callback s() :: %Norm.Core.Schema{}

  defmacro __using__(_) do
    quote do
      @behaviour Definition.Schema

      import Norm
      import Definition.Schema.{Type, Validation}
    end
  end
end
