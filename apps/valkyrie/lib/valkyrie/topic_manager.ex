defmodule Valkyrie.TopicManager do
  @moduledoc """
  Create Topics in kafka using the Elsa library.
  """
  use Retry

  @initial_delay Application.get_env(:valkyrie, :retry_initial_delay)
  @retries Application.get_env(:valkyrie, :retry_count)

  @spec setup_topics(%SmartCity.Dataset{}) :: %{input_topic: String.t(), output_topic: String.t()}
  def setup_topics(dataset) do
    input_topic = input_topic(dataset.id)
    output_topic = output_topic(dataset.id)

    Elsa.create_topic(endpoints(), input_topic)

    wait_for_topic(input_topic)
    wait_for_topic(output_topic)

    %{input_topic: input_topic, output_topic: output_topic}
  end

  def wait_for_topic(topic) do
    retry with: @initial_delay |> exponential_backoff() |> Stream.take(@retries), atoms: [false] do
      Elsa.topic?(endpoints(), topic)
    after
      true ->
        nil
    else
      _ -> raise "Timed out waiting for #{topic} to be available"
    end
  end

  defp endpoints(), do: Application.get_env(:valkyrie, :elsa_brokers)
  defp output_topic_prefix(), do: Application.get_env(:valkyrie, :output_topic_prefix)
  defp output_topic(dataset_id), do: "#{output_topic_prefix()}-#{dataset_id}"
  defp input_topic_prefix(), do: Application.get_env(:valkyrie, :input_topic_prefix)
  defp input_topic(dataset_id), do: "#{input_topic_prefix()}-#{dataset_id}"
end
