defmodule Forklift.TopicManager do
  @moduledoc """
  Create Topics in kafka using the Elsa library.
  """
  use Retry

  alias Forklift.Datasets.DatasetSchema

  @initial_delay Application.get_env(:forklift, :retry_initial_delay)
  @retries Application.get_env(:forklift, :retry_count)

  @spec setup_topics(%DatasetSchema{}) :: %{input_topic: String.t()}
  def setup_topics(schema) do
    input_topic = input_topic(schema.id)

    Elsa.create_topic(endpoints(), input_topic)

    wait_for_topic(input_topic)

    %{input_topic: input_topic}
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

  def endpoints(), do: Application.get_env(:forklift, :elsa_brokers)
  def input_topic_prefix(), do: Application.get_env(:forklift, :input_topic_prefix)
  def input_topic(dataset_id), do: "#{input_topic_prefix()}-#{dataset_id}"
  def output_topic(), do: Application.get_env(:forklift, :output_topic)
end
