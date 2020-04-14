defmodule Provider.Exceptions.ProviderNotFound do
  # credo:disable-for-this-file Credo.Check.Consistency.ExceptionNames
  defexception message: "Provider could not be found"
end

defmodule Provider.Exceptions.ProviderError do
  defexception message: "Provider could not be executed"
end
