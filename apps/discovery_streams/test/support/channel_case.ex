defmodule CotaStreamingConsumerWeb.ChannelCase do
  @moduledoc "false"
  use ExUnit.CaseTemplate

  using do
    quote do
      use Phoenix.ChannelTest

      @endpoint CotaStreamingConsumerWeb.Endpoint
    end
  end

  setup _tags do
    :ok
  end
end
