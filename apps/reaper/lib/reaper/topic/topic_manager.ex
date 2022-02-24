defmodule Reaper.Topic.TopicManager do
  @moduledoc """
  Manages the topics in kafka using Elsa library.
  """
  use Properties, otp_app: :reaper

  require Logger

  getter(:elsa_brokers, generic: true)
  getter(:output_topic_prefix, generic: true)

  def delete_topic(ingestion_id) do
    output_topic = output_topic(ingestion_id)

    case Elsa.delete_topic(elsa_brokers(), output_topic) do
      :ok ->
        Logger.debug("#{__MODULE__}: Deleted topic: #{output_topic}")

      {:error, error} ->
        Logger.error("#{__MODULE__}: Failed to delete topic: #{output_topic}, Reason: #{inspect(error)}")
    end
  end

  defp output_topic(ingestion_id), do: "#{output_topic_prefix()}-#{ingestion_id}"
end
