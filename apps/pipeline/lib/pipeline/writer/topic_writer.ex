defmodule Pipeline.Writer.TopicWriter do
  @moduledoc """
  Implementation of `Pipeline.Writer` for Kafka topics.
  """

  @behaviour Pipeline.Writer
  alias Pipeline.Writer.TopicWriter.InitTask

  @impl Pipeline.Writer
  @doc """
  Sets up infrastructure to produce messages to a Kafka topic. Includes creating
  the topic if necessary.

  Requires arugments:
  * `instance` - Unique caller identity, e.g. application name
  * `topic` - Topic name
  * `producer_name` - Unique Kafka producer identity
  * `endpoints` - Kafka broker endpoints

  Optional args:
  * `retry_count` - Times to retry topic creation. Defaults to 10.
  * `retry_delay` - Milliseconds to initially wait before retrying. Defaults to 100
  """
  def init(args) do
    case DynamicSupervisor.start_child(Pipeline.DynamicSupervisor, {InitTask, args}) do
      {:ok, _} -> :ok
      error -> {:error, error}
    end
  end

  @impl Pipeline.Writer
  @doc """
  Writes data to a Kafka topic.

  Requires configuration:
  * `instance` - Unique caller identity, e.g. appliation name
  * `producer_name` - Unique Kafka producer identity
  """
  def write(content, opts) when is_list(content) do
    instance_producer = producer(opts)

    {:ok, topic} = Registry.meta(Pipeline.Registry, instance_producer)
    Elsa.produce(instance_producer, topic, content)
  end

  @impl Pipeline.Writer
  def terminate(_), do: :ok

  defp producer(config) do
    instance = Keyword.fetch!(config, :instance)
    producer_name = Keyword.fetch!(config, :producer_name)

    :"#{instance}-#{producer_name}"
  end
end
