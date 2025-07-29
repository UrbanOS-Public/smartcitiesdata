defmodule DiscoveryStreams.InitTest do
  use DiscoveryStreamsWeb.ChannelCase
  import Mox

  setup :verify_on_exit!

  setup do
    expect(BrookViewStateMock, :get_all, fn _, _ ->
      {:ok,
       %{
         "Bianco_Lily__Ochre_Black_XOHUE" => "2f3e26b3-89a9-4837-a780-5364587ecbc1",
         "Giallo_Alfie__Citrine_Red_EQDNZ" => "884bd4be-4d0b-47d2-ac88-069e04f3a0fc"
       }}
    end)

    :ok
  end

  test "Creates streams with proper parameters" do
    expect(StreamSupervisorMock, :start_child, fn "2f3e26b3-89a9-4837-a780-5364587ecbc1" -> :does_not_matter end)
    expect(StreamSupervisorMock, :start_child, fn "884bd4be-4d0b-47d2-ac88-069e04f3a0fc" -> :does_not_matter end)

    DiscoveryStreams.Init.on_start(:does_not_matter)
  end
end
