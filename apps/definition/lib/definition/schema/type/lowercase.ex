defmodule Definition.Schema.Type.Lowercase do
  @moduledoc """
  Implementation of `Norm.Conformer.Comformable` that will coerce
  a string into all lowercase letters.

  Use `Definition.Schema.Type.lowercase_string/0` when you need
  this functionality.
  """
  defstruct []

  defimpl Norm.Conformer.Conformable do
    def conform(_spec, input, _path) when is_binary(input) do
      {:ok, String.downcase(input)}
    end

    def conform(_spec, input, path) do
      {:error, [Norm.Conformer.error(path, input, "is not a binary")]}
    end
  end
end
