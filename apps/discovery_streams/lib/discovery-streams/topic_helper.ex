defmodule DiscoveryStreams.TopicHelper do
  @moduledoc false

  use Properties, otp_app: :discovery_streams
  require Logger

  getter(:endpoints, generic: true)
  getter(:topic_prefix, generic: true, default: "transformed-")
  
  defp elsa() do
    Application.get_env(:discovery_streams, :elsa, Elsa)
  end

  def topic_name(dataset_id) do
    "#{topic_prefix()}#{dataset_id}"
  end

  def dataset_id(topic_name) do
    String.split(topic_name, topic_prefix())
    |> List.last()
  end

  def get_endpoints() do
    endpoints()
  end

  def delete_input_topic(dataset_id) do
    input_topic = input_topic(dataset_id)
    Logger.debug("#{__MODULE__}: Deleting Topic: #{input_topic}")

    case elsa().delete_topic(get_endpoints(), input_topic) do
      :ok ->
        Logger.debug("#{__MODULE__}: Deleted topic: #{input_topic}")

      {:error, error} ->
        Logger.error("#{__MODULE__}: Failed to delete topic: #{input_topic}, Reason: #{inspect(error)}")
    end
  end

  defp input_topic(dataset_id), do: "#{topic_prefix()}#{dataset_id}"
end
