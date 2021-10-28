defmodule DiscoveryStreamsWeb.StreamingChannelTest do
  alias DiscoveryStreams.Services.RaptorService
  use DiscoveryStreamsWeb.ChannelCase
  use Placebo

  @dataset_1_id "d21d5af6-346c-43e5-891f-8c2c7f28e4ab"

  setup do
    allow(Brook.get(any(), :streaming_datasets_by_system_name, any()),
      return: {:error, "does_not_exist"}
    )

    allow(Brook.get(any(), :streaming_datasets_by_system_name, "shuttle-position"),
      return: {:ok, @dataset_1_id}
    )

    allow(RaptorService.is_authorized(any(), any()),
      return: true
    )

    :ok
  end

  test "filter events cause all subsequent messages to be pushed to cache through filter in channel" do
    {:ok, _, socket} =
      subscribe_and_join(
        socket(DiscoveryStreamsWeb.UserSocket),
        DiscoveryStreamsWeb.StreamingChannel,
        "streaming:shuttle-position"
      )

    push(socket, "filter", %{"foo.bar" => "12342"})
    broadcast_from(socket, "update", %{"foo" => %{"bar" => "12342"}})
    broadcast_from(socket, "update", %{"foo" => %{"bar" => "98765"}})

    assert_push("update", %{"foo" => %{"bar" => "12342"}})
    refute_push("update", %{"foo" => %{"bar" => "98765"}})

    leave(socket)
  end

  test "filter fields on cache with multiple values causes non-matches to be filtered out in channel" do
    {:ok, _, socket} =
      subscribe_and_join(
        socket(DiscoveryStreamsWeb.UserSocket),
        DiscoveryStreamsWeb.StreamingChannel,
        "streaming:shuttle-position"
      )

    push(socket, "filter", %{"foo.bar" => ["12342", "12349"]})
    broadcast_from(socket, "update", %{"foo" => %{"bar" => "12342"}})
    broadcast_from(socket, "update", %{"foo" => %{"bar" => "98765"}})
    broadcast_from(socket, "update", %{"foo" => %{"bar" => "12349"}})
    broadcast_from(socket, "update", %{"foo" => %{"bar" => "00000"}})
    broadcast_from(socket, "update", %{"foo" => %{"bar" => "55555"}})

    assert_push("update", %{"foo" => %{"bar" => "12342"}})
    assert_push("update", %{"foo" => %{"bar" => "12349"}})

    refute_push("update", %{"foo" => %{"bar" => "98765"}})
    refute_push("update", %{"foo" => %{"bar" => "00000"}})
    refute_push("update", %{"foo" => %{"bar" => "55555"}})

    leave(socket)
  end

  test "filters with multiple keys must all match for message to get pushed" do
    {:ok, _, socket} =
      subscribe_and_join(
        socket(DiscoveryStreamsWeb.UserSocket),
        DiscoveryStreamsWeb.StreamingChannel,
        "streaming:shuttle-position"
      )

    push(socket, "filter", %{"foo.bar" => 1, "abc.def" => "two"})

    broadcast_from(socket, "update", %{"foo" => %{"bar" => 1}, "abc" => %{"def" => "two"}})
    broadcast_from(socket, "update", %{"foo" => %{"bar" => 2}, "abc" => %{"def" => "two"}})
    broadcast_from(socket, "update", %{"foo" => %{"bar" => 1}, "abc" => %{"def" => "three"}})

    assert_push("update", %{"foo" => %{"bar" => 1}, "abc" => %{"def" => "two"}})

    refute_push("update", %{"foo" => %{"bar" => 2}, "abc" => %{"def" => "two"}})
    refute_push("update", %{"foo" => %{"bar" => 1}, "abc" => %{"def" => "three"}})

    leave(socket)
  end

  test "empty filter events cause all subsequent messages to be pushed" do
    {:ok, _, socket} =
      subscribe_and_join(
        socket(DiscoveryStreamsWeb.UserSocket),
        DiscoveryStreamsWeb.StreamingChannel,
        "streaming:shuttle-position"
      )

    push(socket, "filter", %{})

    broadcast_from(socket, "update", %{"one" => 1})
    broadcast_from(socket, "update", %{"two" => 2})

    assert_push("update", %{"one" => 1})
    assert_push("update", %{"two" => 2})

    leave(socket)
  end

  test "joining topic that does not exist returns error tuple" do
    assert {:error, %{reason: "Channel streaming:three does not exist"}} ==
             subscribe_and_join(
               socket(DiscoveryStreamsWeb.UserSocket),
               DiscoveryStreamsWeb.StreamingChannel,
               "streaming:three"
             )
  end

  test "joining unauthorized topic returns error tuple" do
    allow(RaptorService.is_authorized(any(), any()),
      return: false
    )

    assert {:error, %{reason: "Unauthorized to connect to channel streaming:shuttle-position"}} ==
             subscribe_and_join(
               socket(DiscoveryStreamsWeb.UserSocket),
               DiscoveryStreamsWeb.StreamingChannel,
               "streaming:shuttle-position"
             )
  end

  test "API key and system name are passed to Raptor" do
    api_key = "abcdefg"

    DiscoveryStreamsWeb.StreamingChannel.join(
      "streaming:shuttle-position",
      %{"api_key" => api_key},
      socket(DiscoveryStreamsWeb.UserSocket)
    )

    assert_called(RaptorService.is_authorized(api_key, "shuttle-position"))
  end
end
