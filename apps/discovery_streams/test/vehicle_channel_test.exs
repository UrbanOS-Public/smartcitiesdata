defmodule CotaStreamingConsumerWeb.VehicleChannelTest do
  use CotaStreamingConsumerWeb.ChannelCase
  @cache Application.get_env(:cota_streaming_consumer, :cache)

  setup do
    Cachex.clear(@cache)

    {:ok, _, socket} = subscribe_and_join(socket(), CotaStreamingConsumerWeb.VehicleChannel, "vehicle_position")

    on_exit fn -> leave(socket) end

    [socket: socket]
  end

  test "sends the user the cache when they connect" do
    Cachex.put(@cache, "12342", %{"vehicleid" => "12342"})

    {:ok, _, socket} = subscribe_and_join(socket(), CotaStreamingConsumerWeb.VehicleChannel, "vehicle_position")

    assert_push("update", %{"vehicleid" => "12342"}, 1000)

    leave(socket)
  end

  test "filter events cause all cached messages to be pushed through filter", %{socket: socket} do
    Cachex.put(@cache, "12342", %{"foo" => %{"bar" => "12342"}})
    Cachex.put(@cache, "98765", %{"foo" => %{"bar" => "98765"}})

    push socket, "filter", %{"foo.bar" => "12342"}
    assert_push "update", %{"foo" => %{"bar" => "12342"}}
    refute_push "update", %{"foo" => %{"bar" => "98765"}}
  end

  test "filter events cause all subsequent messages to be pushed through filter", %{socket: socket} do
      push socket, "filter", %{"foo.bar" => "12342"}
      broadcast_from socket, "update", %{"foo" => %{"bar" => "12342"}}
      broadcast_from socket, "update", %{"foo" => %{"bar" => "98765"}}

      assert_push "update", %{"foo" => %{"bar" => "12342"}}
      refute_push "update", %{"foo" => %{"bar" => "98765"}}
  end

  test "filter fields with multiple values causes non-matches to be filtered out", %{socket: socket} do
      push socket, "filter", %{"foo.bar" => ["12342", "12349"]}
      broadcast_from socket, "update", %{"foo" => %{"bar" => "12342"}}
      broadcast_from socket, "update", %{"foo" => %{"bar" => "98765"}}
      broadcast_from socket, "update", %{"foo" => %{"bar" => "12349"}}
      broadcast_from socket, "update", %{"foo" => %{"bar" => "00000"}}
      broadcast_from socket, "update", %{"foo" => %{"bar" => "55555"}}

      assert_push "update", %{"foo" => %{"bar" => "12342"}}
      assert_push "update", %{"foo" => %{"bar" => "12349"}}

      refute_push "update", %{"foo" => %{"bar" => "98765"}}
      refute_push "update", %{"foo" => %{"bar" => "00000"}}
      refute_push "update", %{"foo" => %{"bar" => "55555"}}
  end

  test "filters with multiple keys must all match for message to get pushed", %{socket: socket} do
    push socket, "filter", %{"foo.bar" => 1, "abc.def" => "two"}

    broadcast_from socket, "update", %{"foo" => %{"bar" => 1}, "abc" => %{"def" => "two"}}
    broadcast_from socket, "update", %{"foo" => %{"bar" => 2}, "abc" => %{"def" => "two"}}
    broadcast_from socket, "update", %{"foo" => %{"bar" => 1}, "abc" => %{"def" => "three"}}

    assert_push "update", %{"foo" => %{"bar" => 1}, "abc" => %{"def" => "two"}}

    refute_push "update", %{"foo" => %{"bar" => 2}, "abc" => %{"def" => "two"}}
    refute_push "update", %{"foo" => %{"bar" => 1}, "abc" => %{"def" => "three"}}
  end

  test "empty filter events cause all cached messages to be pushed", %{socket: socket} do
    Cachex.put(@cache, "123456", %{"foo" => %{"bar" => "123456"}})
    Cachex.put(@cache, "test42", %{"foo" => %{"bar" => "test42"}})

    push socket, "filter", %{"foo.bar" => "cyan"}
    refute_push "update", %{"foo" => _}

    push socket, "filter", %{}
    assert_push "update", %{"foo" => %{"bar" => "123456"}}
    assert_push "update", %{"foo" => %{"bar" => "test42"}}
  end

  test "empty filter events cause all subsequent messages to be pushed", %{socket: socket} do
    push socket, "filter", %{}

    broadcast_from socket, "update", %{"one" => 1}
    broadcast_from socket, "update", %{"two" => 2}

    assert_push "update", %{"one" => 1}
    assert_push "update", %{"two" => 2}
  end

end
