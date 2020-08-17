defmodule DiscoveryStreamsWeb.StreamingChannelTest do
  use DiscoveryStreamsWeb.ChannelCase
  use Placebo

  alias DiscoveryStreams.{CachexSupervisor, TopicSubscriber}
  @dataset_1_id "d21d5af6-346c-43e5-891f-8c2c7f28e4ab"

  setup do
    CachexSupervisor.create_cache(@dataset_1_id |> String.to_atom())
    Cachex.clear(@dataset_1_id |> String.to_atom())

    allow TopicSubscriber.list_subscribed_topics(),
      return: ["transformed-#{@dataset_1_id}"]

    allow(Brook.get(any(), :streaming_datasets_by_system_name, any()),
      return: {:error, "does_not_exist"}
    )

    allow(Brook.get(any(), :streaming_datasets_by_system_name, "shuttle-position"),
      return: {:ok, @dataset_1_id}
    )

    :ok
  end

  test "sends the user the entire cache in of a topic stream" do
    Cachex.put(:"d21d5af6-346c-43e5-891f-8c2c7f28e4ab", "12345", %{"shuttleid" => "12345"})
    Cachex.put(:"d21d5af6-346c-43e5-891f-8c2c7f28e4ab", "98765", %{"shuttleid" => "98765"})

    {:ok, _, socket} =
      subscribe_and_join(
        socket(DiscoveryStreamsWeb.UserSocket),
        DiscoveryStreamsWeb.StreamingChannel,
        "streaming:shuttle-position"
      )

    assert_push("update", %{"shuttleid" => "12345"}, 1000)
    assert_push("update", %{"shuttleid" => "98765"}, 1000)

    leave(socket)
  end

  test "sends the user the entire cache when they connect with no filter to channel" do
    Cachex.put(:"d21d5af6-346c-43e5-891f-8c2c7f28e4ab", "12342", %{"vehicleid" => "12342"})
    Cachex.put(:"d21d5af6-346c-43e5-891f-8c2c7f28e4ab", "54321", %{"vehicleid" => "54321"})

    {:ok, _, socket} =
      subscribe_and_join(
        socket(DiscoveryStreamsWeb.UserSocket),
        DiscoveryStreamsWeb.StreamingChannel,
        "streaming:shuttle-position"
      )

    assert_push("update", %{"vehicleid" => "12342"}, 1000)
    assert_push("update", %{"vehicleid" => "54321"}, 1000)

    leave(socket)
  end

  test "sends the user the cache that matches filter given on params when they connect to channel" do
    Cachex.put(:"d21d5af6-346c-43e5-891f-8c2c7f28e4ab", "12345", %{"vehicleid" => "12345", "type" => "car"})
    Cachex.put(:"d21d5af6-346c-43e5-891f-8c2c7f28e4ab", "54321", %{"vehicleid" => "54321", "type" => "bus"})

    {:ok, _, socket} =
      subscribe_and_join(
        socket(DiscoveryStreamsWeb.UserSocket),
        DiscoveryStreamsWeb.StreamingChannel,
        "streaming:shuttle-position",
        %{
          "type" => "bus"
        }
      )

    refute_push("update", %{"vehicleid" => "12345", "type" => "car"}, 1000)
    assert_push("update", %{"vehicleid" => "54321", "type" => "bus"}, 1000)

    leave(socket)
  end

  test "filter events cause all cached messages in cache to be pushed through filter in channel" do
    {:ok, _, socket} =
      subscribe_and_join(
        socket(DiscoveryStreamsWeb.UserSocket),
        DiscoveryStreamsWeb.StreamingChannel,
        "streaming:shuttle-position"
      )

    Cachex.put(:"d21d5af6-346c-43e5-891f-8c2c7f28e4ab", "12342", %{"foo" => %{"bar" => "12342"}})
    Cachex.put(:"d21d5af6-346c-43e5-891f-8c2c7f28e4ab", "98765", %{"foo" => %{"bar" => "98765"}})

    push(socket, "filter", %{"foo.bar" => "12342"})

    assert_push("update", %{"foo" => %{"bar" => "12342"}})
    refute_push("update", %{"foo" => %{"bar" => "98765"}})

    leave(socket)
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

  test "empty filter events cause all cached messages to be pushed" do
    {:ok, _, socket} =
      subscribe_and_join(
        socket(DiscoveryStreamsWeb.UserSocket),
        DiscoveryStreamsWeb.StreamingChannel,
        "streaming:shuttle-position"
      )

    Cachex.put(:"d21d5af6-346c-43e5-891f-8c2c7f28e4ab", "123456", %{"foo" => %{"bar" => "123456"}})
    Cachex.put(:"d21d5af6-346c-43e5-891f-8c2c7f28e4ab", "test42", %{"foo" => %{"bar" => "test42"}})

    push(socket, "filter", %{"foo.bar" => "cyan"})
    refute_push("update", %{"foo" => _})

    push(socket, "filter", %{})
    assert_push("update", %{"foo" => %{"bar" => "123456"}})
    assert_push("update", %{"foo" => %{"bar" => "test42"}})

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
end
