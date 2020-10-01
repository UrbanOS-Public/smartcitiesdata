defmodule Valkyrie.InitTest do
  use ExUnit.Case
  use Placebo

  setup do
    allow(Brook.get_all(any(), :datasets_by_id),
      return:
      {:ok,
       %{
         "2f3e26b3-89a9-4837-a780-5364587ecbc1" => [%{"type" => "string", "name" => "first"}],
         "884bd4be-4d0b-47d2-ac88-069e04f3a0fc" => [%{"type" => "string", "name" => "first"}]
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
