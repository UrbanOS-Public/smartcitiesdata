defmodule DiscoveryStreams.TopicHelper do
  @moduledoc false

  def topic_name(dataset_id) do
    "#{topic_prefix()}#{dataset_id}"
  end

  def dataset_id(topic_name) do
    String.split(topic_name, topic_prefix())
    |> List.last()
  end

  defp topic_prefix() do
    Application.get_env(:discovery_streams, :topic_prefix, "transformed-")
  end
end
