defmodule IdGenerator do
  @callback uuid4() :: String.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour IdGenerator
      def uuid4, do: UUID.uuid4()
    end
  end
end

defmodule IdGenerator.Impl do
  use IdGenerator
end
