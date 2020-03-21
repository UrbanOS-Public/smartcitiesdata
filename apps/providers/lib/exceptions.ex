defmodule Provider.Exceptions.ProviderNotFound do
  defexception message: "Provider could not be found"
end

defmodule Provider.Exceptions.ProviderError do
  defexception message: "Provider could not be executed"
end
