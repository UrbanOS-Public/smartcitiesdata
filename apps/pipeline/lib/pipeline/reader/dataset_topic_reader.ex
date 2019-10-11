defmodule Pipeline.Reader.DatasetTopicReader do
  @moduledoc """
  Implementation of `Pipeline.Reader` for dataset Kafka topics.
  """

  @behaviour Pipeline.Reader
  alias Pipeline.Reader.DatasetTopicReader.InitTask

  @type init_args() :: [
          instance: atom(),
          dataset: SmartCity.Dataset.t(),
          endpoints: Elsa.endpoints(),
          input_topic_prefix: String.t(),
          handler: module()
        ]

  @type term_args() :: [
          instance: atom(),
          dataset: SmartCity.Dataset.t(),
          input_topic_prefix: String.t()
        ]

  @impl Pipeline.Reader
  @spec init(init_args()) :: :ok | {:error, term()}
  @doc """
  Sets up infrastructure to consume messages off a dataset Kafka topic. Includes creating the
  topic if necessary.

  Optional arguments:
  * `retry_count` - Times to retry topic creation. Defaults to 10
  * `retry_delay` - Milliseconds to initially wait before retrying. Defaults to 100
  * `topic_subscriber_config` - Subscriber configuration passed to underlying libraries. Defaults to `[]`
  """
  def init(args) do
    case DynamicSupervisor.start_child(Pipeline.DynamicSupervisor, {InitTask, args}) do
      {:ok, _} -> :ok
      error -> {:error, error}
    end
  end

  @impl Pipeline.Reader
  @spec terminate(term_args()) :: :ok | {:error, term()}
  @doc """
  Destroys topic consumer infrastructure.
  """
  def terminate(args) do
    with connection <- connection(args),
         {:ok, pid} <- Registry.meta(Pipeline.Registry, connection) do
      DynamicSupervisor.terminate_child(Pipeline.DynamicSupervisor, pid)
    end
  end

  defp connection(args) do
    instance = Keyword.fetch!(args, :instance)
    prefix = Keyword.fetch!(args, :input_topic_prefix)
    dataset = Keyword.fetch!(args, :dataset)

    :"#{instance}-#{prefix}-#{dataset.id}-consumer"
  end
end
