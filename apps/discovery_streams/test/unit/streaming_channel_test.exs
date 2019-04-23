defmodule DiscoveryStreamsWeb.StreamingChannelTest do
  use DiscoveryStreamsWeb.ChannelCase
  use Placebo

  import Checkov

  alias DiscoveryStreams.{CachexSupervisor, TopicSubscriber}

  setup do
    CachexSupervisor.create_cache(:"shuttle-position")
    CachexSupervisor.create_cache(:central_ohio_transit_authority__cota_stream)
    Cachex.clear(:"shuttle-position")
    Cachex.clear(:central_ohio_transit_authority__cota_stream)

    allow TopicSubscriber.list_subscribed_topics(),
      return: ["shuttle-position", "central_ohio_transit_authority__cota_stream"]

    :ok
  end

  data_test "presence is tracked per channel - #{channel}" do
    {:ok, _, socket} = subscribe_and_join(socket(), DiscoveryStreamsWeb.StreamingChannel, channel)

    assert 1 == DiscoveryStreamsWeb.Presence.connections(channel)

    leave(socket)

    where([
      [:cache, :channel],
      [:"shuttle-position", "streaming:shuttle-position"],
      [:central_ohio_transit_authority__cota_stream, "vehicle_position"]
    ])
  end

  data_test "sends the user the entire cache in #{cache} of a #{channel} topic stream" do
    Cachex.put(cache, "12345", %{"shuttleid" => "12345"})
    Cachex.put(cache, "98765", %{"shuttleid" => "98765"})

    {:ok, _, socket} = subscribe_and_join(socket(), DiscoveryStreamsWeb.StreamingChannel, channel)

    assert_push("update", %{"shuttleid" => "12345"}, 1000)
    assert_push("update", %{"shuttleid" => "98765"}, 1000)

    leave(socket)

    where([
      [:cache, :channel],
      [:"shuttle-position", "streaming:shuttle-position"],
      [:central_ohio_transit_authority__cota_stream, "vehicle_position"]
    ])
  end

  data_test "sends the user the entire cache in #{cache} when they connect with no filter to channal #{channel}" do
    Cachex.put(cache, "12342", %{"vehicleid" => "12342"})
    Cachex.put(cache, "54321", %{"vehicleid" => "54321"})

    {:ok, _, socket} = subscribe_and_join(socket(), DiscoveryStreamsWeb.StreamingChannel, channel)

    assert_push("update", %{"vehicleid" => "12342"}, 1000)
    assert_push("update", %{"vehicleid" => "54321"}, 1000)

    leave(socket)

    where([
      [:cache, :channel],
      [:"shuttle-position", "streaming:shuttle-position"],
      [:central_ohio_transit_authority__cota_stream, "vehicle_position"]
    ])
  end

  data_test "sends the user the cache in #{cache} that matches filter given on params when they connect to channel #{
              channel
            }" do
    Cachex.put(cache, "12345", %{"vehicleid" => "12345", "type" => "car"})
    Cachex.put(cache, "54321", %{"vehicleid" => "54321", "type" => "bus"})

    {:ok, _, socket} = subscribe_and_join(socket(), DiscoveryStreamsWeb.StreamingChannel, channel, %{"type" => "bus"})

    refute_push("update", %{"vehicleid" => "12345", "type" => "car"}, 1000)
    assert_push("update", %{"vehicleid" => "54321", "type" => "bus"}, 1000)

    leave(socket)

    where([
      [:cache, :channel],
      [:"shuttle-position", "streaming:shuttle-position"],
      [:central_ohio_transit_authority__cota_stream, "vehicle_position"]
    ])
  end

  data_test "filter events cause all cached messages in cache #{cache} to be pushed through filter in channel #{channel}" do
    {:ok, _, socket} = subscribe_and_join(socket(), DiscoveryStreamsWeb.StreamingChannel, channel)

    Cachex.put(cache, "12342", %{"foo" => %{"bar" => "12342"}})
    Cachex.put(cache, "98765", %{"foo" => %{"bar" => "98765"}})

    push(socket, "filter", %{"foo.bar" => "12342"})

    assert_push("update", %{"foo" => %{"bar" => "12342"}})
    refute_push("update", %{"foo" => %{"bar" => "98765"}})

    leave(socket)

    where([
      [:cache, :channel],
      [:"shuttle-position", "streaming:shuttle-position"],
      [:central_ohio_transit_authority__cota_stream, "vehicle_position"]
    ])
  end

  data_test "filter events cause all subsequent messages to be pushed to cache #{cache} through filter in channel #{
              channel
            }" do
    {:ok, _, socket} = subscribe_and_join(socket(), DiscoveryStreamsWeb.StreamingChannel, channel)

    push(socket, "filter", %{"foo.bar" => "12342"})
    broadcast_from(socket, "update", %{"foo" => %{"bar" => "12342"}})
    broadcast_from(socket, "update", %{"foo" => %{"bar" => "98765"}})

    assert_push("update", %{"foo" => %{"bar" => "12342"}})
    refute_push("update", %{"foo" => %{"bar" => "98765"}})

    leave(socket)

    where([
      [:cache, :channel],
      [:"shuttle-position", "streaming:shuttle-position"],
      [:central_ohio_transit_authority__cota_stream, "vehicle_position"]
    ])
  end

  data_test "filter fields on cache #{cache} with multiple values causes non-matches to be filtered out in channel #{
              channel
            }" do
    {:ok, _, socket} = subscribe_and_join(socket(), DiscoveryStreamsWeb.StreamingChannel, channel)

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

    where([
      [:cache, :channel],
      [:"shuttle-position", "streaming:shuttle-position"],
      [:central_ohio_transit_authority__cota_stream, "vehicle_position"]
    ])
  end

  data_test "filters with multiple keys must all match for message to get pushed" do
    {:ok, _, socket} = subscribe_and_join(socket(), DiscoveryStreamsWeb.StreamingChannel, channel)

    push(socket, "filter", %{"foo.bar" => 1, "abc.def" => "two"})

    broadcast_from(socket, "update", %{"foo" => %{"bar" => 1}, "abc" => %{"def" => "two"}})
    broadcast_from(socket, "update", %{"foo" => %{"bar" => 2}, "abc" => %{"def" => "two"}})
    broadcast_from(socket, "update", %{"foo" => %{"bar" => 1}, "abc" => %{"def" => "three"}})

    assert_push("update", %{"foo" => %{"bar" => 1}, "abc" => %{"def" => "two"}})

    refute_push("update", %{"foo" => %{"bar" => 2}, "abc" => %{"def" => "two"}})
    refute_push("update", %{"foo" => %{"bar" => 1}, "abc" => %{"def" => "three"}})

    leave(socket)

    where([
      [:cache, :channel],
      [:"shuttle-position", "streaming:shuttle-position"],
      [:central_ohio_transit_authority__cota_stream, "vehicle_position"]
    ])
  end

  data_test "empty filter events cause all cached messages to be pushed" do
    {:ok, _, socket} = subscribe_and_join(socket(), DiscoveryStreamsWeb.StreamingChannel, channel)

    Cachex.put(cache, "123456", %{"foo" => %{"bar" => "123456"}})
    Cachex.put(cache, "test42", %{"foo" => %{"bar" => "test42"}})

    push(socket, "filter", %{"foo.bar" => "cyan"})
    refute_push("update", %{"foo" => _})

    push(socket, "filter", %{})
    assert_push("update", %{"foo" => %{"bar" => "123456"}})
    assert_push("update", %{"foo" => %{"bar" => "test42"}})

    leave(socket)

    where([
      [:cache, :channel],
      [:"shuttle-position", "streaming:shuttle-position"],
      [:central_ohio_transit_authority__cota_stream, "vehicle_position"]
    ])
  end

  data_test "empty filter events cause all subsequent messages to be pushed" do
    {:ok, _, socket} = subscribe_and_join(socket(), DiscoveryStreamsWeb.StreamingChannel, channel)

    push(socket, "filter", %{})

    broadcast_from(socket, "update", %{"one" => 1})
    broadcast_from(socket, "update", %{"two" => 2})

    assert_push("update", %{"one" => 1})
    assert_push("update", %{"two" => 2})

    leave(socket)

    where([
      [:cache, :channel],
      [:"shuttle-position", "streaming:shuttle-position"],
      [:central_ohio_transit_authority__cota_stream, "vehicle_position"]
    ])
  end

  test "joining topic that does not exist returns error tuple" do
    assert {:error, %{reason: "Channel streaming:three does not exist"}} ==
             subscribe_and_join(socket(), DiscoveryStreamsWeb.StreamingChannel, "streaming:three")
  end
end
