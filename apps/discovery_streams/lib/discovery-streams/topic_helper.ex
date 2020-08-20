defmodule DiscoveryStreams.TopicHelper do
  @moduledoc false

  require Logger

  def topic_name(dataset_id) do
    "#{topic_prefix()}#{dataset_id}"
  end

  def dataset_id(topic_name) do
    String.split(topic_name, topic_prefix())
    |> List.last()
  end

  def get_endpoints() do
    Application.get_env(:discovery_streams, :endpoints)
  end

  def delete_input_topic(dataset_id) do
    input_topic = input_topic(dataset_id)
    Logger.debug("#{__MODULE__}: Deleting Topic: #{input_topic}")

    case Elsa.delete_topic(get_endpoints(), input_topic) do
      :ok ->
        Logger.debug("#{__MODULE__}: Deleted topic: #{input_topic}")

      {:error, error} ->
        Logger.error("#{__MODULE__}: Failed to delete topic: #{input_topic}, Reason: #{inspect(error)}")
    end
  end

  defp topic_prefix() do
    Application.get_env(:discovery_streams, :topic_prefix, "transformed-")
  end

  defp input_topic(dataset_id), do: "#{topic_prefix()}#{dataset_id}"
end
