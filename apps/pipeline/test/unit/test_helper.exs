ExUnit.start()
Code.require_file("support/mocks.ex", __DIR__ |> Path.dirname())

# Configure Mox
defmodule Pipeline.TestHelper do
  defmacro __using__(_opts) do
    quote do
      import Mox
      import Pipeline.Test.Mocks

      # Make sure mocks are verified when the test exits
      setup :verify_on_exit!

      # This makes mocks work in async mode
      setup :set_mox_global

      setup do
        # Default stub for TopicReader
        Mox.stub_with(TopicReaderMock, Pipeline.Reader.TopicReader)
        :ok
      end
    end
  end
end
