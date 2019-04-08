defmodule CotaStreamingConsumer.TopicSubscriberTest do
  use ExUnit.Case
  use Divo

  @topics ["cota-vehicle-positions", "shuttle-positions"]

  test "subscribes to any non internal use topic" do
    validate_subscribed_topics(@topics)
    validate_caches_exist(@topics)

    create_topic("just_created")

    validate_subscribed_topics(@topics ++ ["just_created"])
    validate_caches_exist(@topics ++ ["just_created"])
  end

  defp validate_subscribed_topics(expected) do
    Patiently.wait_for!(
      fn ->
        MapSet.new(subscribed_topics()) == MapSet.new(expected)
      end,
      dwell: 200,
      max_tries: 50
    )
  end

  defp validate_caches_exist(expected) do
    Patiently.wait_for!(
      fn ->
        Enum.all?(expected, fn topic -> not match?({:error, _}, Cachex.count(String.to_atom(topic))) end)
      end,
      dwell: 200,
      max_tries: 50
    )
  end

  defp subscribed_topics() do
    Kaffe.GroupManager.list_subscribed_topics()
  end

  defp create_topic(topic) do
    endpoints =
      Application.get_env(:kaffe, :consumer)[:endpoints]
      |> Enum.map(fn {host, port} -> {to_charlist(host), port} end)

    :brod.start_client(endpoints, :test_client)
    :brod.start_producer(:test_client, topic, [])
  end
end
