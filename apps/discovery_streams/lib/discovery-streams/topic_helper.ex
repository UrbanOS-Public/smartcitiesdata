defmodule DiscoveryStreams.TopicHelper do
  @moduledoc false

  def topic_name(dataset_id) do
    "#{topic_prefix()}#{dataset_id}"
  end

  def dataset_id(topic_name) do
    String.split(topic_name, topic_prefix())
    |> List.last()
  end

  def get_endpoints() do
    Application.get_env(:kaffe, :consumer)[:endpoints]
    |> Enum.map(fn {host, port} -> {to_charlist(host), port} end)
  end

  def delete_topic(dataset_id) do
    output_topic = output_topic(dataset_id)
    Elsa.delete_topic(get_endpoints(), output_topic)
  end

  defp topic_prefix() do
    Application.get_env(:discovery_streams, :topic_prefix, "transformed-")
  end

  defp output_topic(dataset_id), do: "#{topic_prefix()}-#{dataset_id}"
end
