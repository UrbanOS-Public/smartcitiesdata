defmodule DiscoveryStreamsWeb.ChannelCase do
  @moduledoc "false"
  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest

      @endpoint DiscoveryStreamsWeb.Endpoint
    end
  end

  setup _tags do
    :ok
  end
end
