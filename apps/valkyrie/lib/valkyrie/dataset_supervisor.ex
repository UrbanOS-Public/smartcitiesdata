defmodule Valkyrie.DatasetSupervisor do
  @moduledoc """
  Supervisor for each dataset that supervises the elsa producer and broadway pipeline.
  """
  use Supervisor

  def name(dataset) do
    :"#{dataset.id}_supervisor"
  end

  def child_spec(args) do
    dataset = Keyword.fetch!(args, :dataset)

    super(args)
    |> Map.put(:id, name(dataset))
  end

  def start_link(opts) do
    dataset = Keyword.fetch!(opts, :dataset)
    Supervisor.start_link(__MODULE__, opts, name: name(dataset))
  end

  @impl Supervisor
  def init(opts) do
    dataset = Keyword.fetch!(opts, :dataset)
    input_topic = Keyword.fetch!(opts, :input_topic)
    output_topic = Keyword.fetch!(opts, :output_topic)
    producer = :"#{dataset.id}_producer"

    children = [
      elsa_producer(dataset, output_topic, producer),
      broadway(dataset, input_topic, output_topic, producer)
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  defp elsa_producer(dataset, topic, producer) do
    %{
      id: :"#{dataset.id}_elsa_producer",
      start: {Elsa.Producer.Manager, :start_producer, [endpoints(), topic, [name: producer]]}
    }
  end

  defp broadway(dataset, input_topic, output_topic, producer) do
    config = [
      dataset: dataset,
      producer: producer,
      name: :"#{dataset.id}_elsa_consumer",
      endpoints: endpoints(),
      group: "valkyrie-#{input_topic}",
      topics: [input_topic],
      config: Application.get_env(:valkyrie, :topic_subscriber_config),
      output_topic: output_topic
    ]

    {Valkyrie.Broadway, config}
  end

  defp endpoints(), do: Application.get_env(:valkyrie, :elsa_brokers)
end
