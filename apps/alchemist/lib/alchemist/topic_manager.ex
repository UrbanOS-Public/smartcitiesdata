defmodule Alchemist.TopicManager do
  @moduledoc """
  Create Topics in kafka using the Elsa library.
  """
  use Retry
  use Properties, otp_app: :alchemist

  getter(:retry_initial_delay, generic: true)
  getter(:retry_count, generic: true)
  getter(:elsa_brokers, generic: true)
  getter(:output_topic_prefix, generic: true)
  getter(:input_topic_prefix, generic: true)

  @spec setup_topics(%SmartCity.Ingestion{}) :: %{input_topic: String.t(), output_topic: String.t()}
  def setup_topics(ingestion) do
    input_topic = input_topic(ingestion.id)
    output_topic = output_topic(ingestion.targetDataset)

    Elsa.create_topic(elsa_brokers(), input_topic)
    Elsa.create_topic(elsa_brokers(), output_topic)
    wait_for_topic(input_topic)
    wait_for_topic(output_topic)

    %{input_topic: input_topic, output_topic: output_topic}
  end

  def delete_topics(ingestion_id) do
    input_topic = input_topic(ingestion_id)
    output_topic = output_topic(ingestion_id)
    Elsa.delete_topic(elsa_brokers(), input_topic)
    Elsa.delete_topic(elsa_brokers(), output_topic)
  end

  def wait_for_topic(topic) do
    retry with: retry_initial_delay() |> exponential_backoff() |> Stream.take(retry_count()), atoms: [false] do
      Elsa.topic?(elsa_brokers(), topic)
    after
      true ->
        nil
    else
      _ -> raise "Timed out waiting for #{topic} to be available"
    end
  end

  defp output_topic(ingestion_id), do: "#{output_topic_prefix()}-#{ingestion_id}"
  defp input_topic(ingestion_id), do: "#{input_topic_prefix()}-#{ingestion_id}"
end
