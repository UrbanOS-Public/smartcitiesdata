defmodule DiscoveryStreams.InitTest do
  use DiscoveryStreamsWeb.ChannelCase
  import Mox

  setup :verify_on_exit!

  setup do
    # Set up dependency injection through Application environment
    Application.put_env(:discovery_streams, :brook_view_state, BrookViewStateMock)
    Application.put_env(:discovery_streams, :stream_supervisor, StreamSupervisorMock)
    
    expect(BrookViewStateMock, :get_all, fn :discovery_streams, :streaming_datasets_by_system_name ->
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

    DiscoveryStreams.Init.on_start(:does_not_matter, BrookViewStateMock, StreamSupervisorMock)
  end
end
