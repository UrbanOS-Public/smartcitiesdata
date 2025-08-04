defmodule DiscoveryStreamsWeb.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import DiscoveryStreamsWeb.Endpoint

      # The default endpoint for testing
      @endpoint DiscoveryStreamsWeb.Endpoint
    end
  end

  setup _tags do
    :ok
  end
end
