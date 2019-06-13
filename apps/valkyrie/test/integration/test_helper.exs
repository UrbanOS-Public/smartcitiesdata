ExUnit.start()

defmodule TestHelpers do
  require Logger

  import Record, only: [defrecord: 2, extract: 2]
  defrecord :kafka_message, extract(:kafka_message, from_lib: "kafka_protocol/include/kpro_public.hrl")

  def clear_timing(%SmartCity.Data{} = data_message) do
    Map.update!(data_message, :operational, fn _ -> %{timing: []} end)
  end

  def extract_dlq_messages(topic, endpoints) do
    topic
    |> fetch_messages(endpoints)
    |> Enum.map(&Jason.decode!(&1, keys: :atoms))
  end

  def extract_data_messages(topic, endpoints) do
    topic
    |> fetch_messages(endpoints)
    |> Enum.map(&SmartCity.Data.new/1)
    |> Enum.map(&elem(&1, 1))
  end

  defp fetch_messages(topic, endpoints) do
    case :brod.fetch(endpoints, topic, 0, 0) do
      {:ok, {_offset, messages}} ->
        messages
        |> Enum.map(&kafka_message(&1, :value))

      {:error, reason} ->
        Logger.warn("Failed to extract messages: #{inspect(reason)}")
        []
    end
  end
end
