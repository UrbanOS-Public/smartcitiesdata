defmodule DiscoveryStreamsWeb.StreamingChannelTest do
  alias RaptorServiceMock
  use DiscoveryStreamsWeb.ChannelCase
  import Mox
  
  setup :verify_on_exit!

  @dataset_1_id "d21d5af6-346c-43e5-891f-8c2c7f28e4ab"

  setup do
    BrookViewStateMock
    |> stub(:get, fn _, _, _ -> {:error, "does_not_exist"} end)

    :ok
  end

  test "filter events cause all subsequent messages to be pushed to cache through filter in channel" do
    BrookViewStateMock
    |> expect(:get, fn _, _, "shuttle-position" -> {:ok, @dataset_1_id} end)
    
    expect(RaptorServiceMock, :is_authorized, fn _, _, _ -> true end)

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
    BrookViewStateMock
    |> expect(:get, fn _, _, "shuttle-position" -> {:ok, @dataset_1_id} end)
    
    expect(RaptorServiceMock, :is_authorized, fn _, _, _ -> true end)

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
    BrookViewStateMock
    |> expect(:get, fn _, _, "shuttle-position" -> {:ok, @dataset_1_id} end)
    
    expect(RaptorServiceMock, :is_authorized, fn _, _, _ -> true end)

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
    BrookViewStateMock
    |> expect(:get, fn _, _, "shuttle-position" -> {:ok, @dataset_1_id} end)
    
    expect(RaptorServiceMock, :is_authorized, fn _, _, _ -> true end)

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
    assert {:error, %{reason: "Channel streaming:three does not exist or you do not have access"}} ==
             subscribe_and_join(
               socket(DiscoveryStreamsWeb.UserSocket),
               DiscoveryStreamsWeb.StreamingChannel,
               "streaming:three"
             )
  end

  test "joining unauthorized topic returns error tuple" do
    BrookViewStateMock
    |> expect(:get, fn _, _, "shuttle-position" -> {:ok, @dataset_1_id} end)
    
    expect(RaptorServiceMock, :is_authorized, fn _, _, _ -> false end)

    assert {:error, %{reason: "Channel streaming:shuttle-position does not exist or you do not have access"}} ==
             subscribe_and_join(
               socket(DiscoveryStreamsWeb.UserSocket),
               DiscoveryStreamsWeb.StreamingChannel,
               "streaming:shuttle-position"
             )
  end

  test "API key and system name are passed to Raptor" do
    api_key = "abcdefg"

    BrookViewStateMock
    |> expect(:get, fn _, _, "shuttle-position" -> {:ok, @dataset_1_id} end)
    
    expect(RaptorServiceMock, :is_authorized, fn _, _, _ -> true end)

    DiscoveryStreamsWeb.StreamingChannel.join(
      "streaming:shuttle-position",
      %{"api_key" => api_key},
      socket(DiscoveryStreamsWeb.UserSocket)
    )

    verify!(RaptorServiceMock)
  end

  describe "REQUIRED_API_KEY" do
    setup do
      System.put_env("REQUIRE_API_KEY", "true")

      on_exit(fn ->
        System.put_env("REQUIRE_API_KEY", "false")
      end)
    end

    test "joining a application with no api_key returns an error" do
      assert {:error, %{reason: "Channel streaming:shuttle-position does not exist or you do not have access"}} ==
               subscribe_and_join(
                 socket(DiscoveryStreamsWeb.UserSocket),
                 DiscoveryStreamsWeb.StreamingChannel,
                 "streaming:shuttle-position"
               )
    end

    test "joining a application with api_key connects" do
      BrookViewStateMock
      |> expect(:get, fn _, _, "shuttle-position" -> {:ok, @dataset_1_id} end)
      
      expect(RaptorServiceMock, :get_user_id_from_api_key, fn _, _ -> {:ok, "user_id"} end)
      expect(RaptorServiceMock, :is_authorized, fn _, _, _ -> true end)

      {:ok, _, socket} =
        subscribe_and_join(
          socket(DiscoveryStreamsWeb.UserSocket),
          DiscoveryStreamsWeb.StreamingChannel,
          "streaming:shuttle-position",
          %{"api_key" => "valid_api_key"}
        )

      leave(socket)
    end

    test "joining a application with invalid api_key returns an error" do
      expect(RaptorServiceMock, :get_user_id_from_api_key, fn _, _ -> {:error, "reason", "500"} end)

      assert {:error, %{reason: "Channel streaming:shuttle-position gave error code 500 with reason reason"}} ==
               subscribe_and_join(
                 socket(DiscoveryStreamsWeb.UserSocket),
                 DiscoveryStreamsWeb.StreamingChannel,
                 "streaming:shuttle-position",
                 %{"api_key" => "valid_api_key"}
               )
    end
  end
end
