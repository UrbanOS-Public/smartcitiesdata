defmodule DiscoveryStreams.InitTest do
  use DiscoveryStreamsWeb.ChannelCase
  use Placebo

  alias DiscoveryStreams.Stream.SourceHandler
  alias SmartCity.TestDataGenerator, as: TDG

  setup do
    allow(Brook.get_all(any(), :streaming_datasets_by_system_name),
      return:
        {:ok,
         %{
           "Bianco_Lily__Ochre_Black_XOHUE" => "2f3e26b3-89a9-4837-a780-5364587ecbc1",
           "Giallo_Alfie__Citrine_Red_EQDNZ" => "884bd4be-4d0b-47d2-ac88-069e04f3a0fc"
         }}
    )

    :ok
  end

  test "Creates streams with proper parameters" do
    expect DiscoveryStreams.Stream.Supervisor.start_child("2f3e26b3-89a9-4837-a780-5364587ecbc1"),
      return: :does_not_matter

    expect DiscoveryStreams.Stream.Supervisor.start_child("884bd4be-4d0b-47d2-ac88-069e04f3a0fc"),
      return: :does_not_matter

    DiscoveryStreams.Init.on_start(:does_not_matter)
  end
end
