ExUnit.start()

defmodule TestHelpers do
  require Elsa.Message
  require Logger

  alias SmartCity.TestDataGenerator, as: TDG

  def clear_timing(%SmartCity.Data{} = data_message) do
    Map.update!(data_message, :operational, fn _ -> %{timing: []} end)
  end

  def get_dlq_messages_from_kafka(topic, endpoints) do
    topic
    |> fetch_messages(endpoints)
    |> Enum.map(&Jason.decode!(&1, keys: :atoms))
  end

  def get_data_messages_from_kafka(topic, endpoints) do
    topic
    |> fetch_messages(endpoints)
    |> Enum.map(&SmartCity.Data.new/1)
    |> Enum.map(&elem(&1, 1))
    |> Enum.map(&TestHelpers.clear_timing/1)
  end

  def get_data_messages_from_kafka_with_timing(topic, endpoints) do
    topic
    |> fetch_messages(endpoints)
    |> Enum.map(&SmartCity.Data.new/1)
    |> Enum.map(&elem(&1, 1))
  end

  def produce_message(message, topic, endpoints) do
    Elsa.Producer.produce(
      endpoints,
      topic,
      {"jerks", Jason.encode!(message)},
      parition: 0
    )
  end

  def produce_messages(messages, topic, endpoints) do
    Enum.each(messages, &produce_message(&1, topic, endpoints))
  end

  def fetch_messages(topic, endpoints) do
    case :brod.fetch(endpoints, topic, 0, 0) do
      {:ok, {_offset, messages}} ->
        messages
        |> Enum.map(&Elsa.Message.kafka_message(&1, :value))

      {:error, reason} ->
        Logger.warn("Failed to extract messages: #{inspect(reason)}")
        []
    end
  end

  def create_data(overrides) do
    overrides
    |> TDG.create_data()
    |> clear_timing()
  end

  def wait_for_topic(endpoints, topic) do
    Patiently.wait_for!(
      fn ->
        Elsa.topic?(endpoints, topic)
      end,
      dwell: 200,
      max_tries: 20
    )
  end
end
