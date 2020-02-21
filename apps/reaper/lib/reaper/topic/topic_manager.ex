defmodule Reaper.Topic.TopicManager do
  @moduledoc """
  Manages the topics in kafka using Elsa library.
  """

  require Logger

  def delete_topic(dataset_id) do
    output_topic = output_topic(dataset_id)

    case Elsa.delete_topic(endpoints(), output_topic) do
      :ok ->
        Logger.debug("#{__MODULE__}: Deleted topic: #{output_topic}")
        :ok

      {:error, error} ->
        Logger.error("#{__MODULE__}: Failed to delete topic: #{output_topic}, Reason: #{inspect(error)}")
    end
  end

  defp endpoints(), do: Application.get_env(:reaper, :elsa_brokers)
  defp output_topic_prefix(), do: Application.get_env(:reaper, :output_topic_prefix)
  defp output_topic(dataset_id), do: "#{output_topic_prefix()}-#{dataset_id}"
end
