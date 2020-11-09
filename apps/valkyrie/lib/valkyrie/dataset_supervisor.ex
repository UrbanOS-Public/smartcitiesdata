defmodule Valkyrie.DatasetSupervisor do
  @moduledoc """
  Supervisor for each dataset that supervises the elsa producer and broadway pipeline.
  """
  use Supervisor
  use Properties, otp_app: :valkyrie

  getter(:topic_subscriber_config, generic: true)
  getter(:elsa_brokers, generic: true)

  def name(id), do: :"#{id}_supervisor"

  def ensure_started(start_options) do
    dataset = Keyword.fetch!(start_options, :dataset)
    stop_dataset_supervisor(dataset.id)

    {:ok, _pid} =
      DynamicSupervisor.start_child(Valkyrie.Dynamic.Supervisor, {Valkyrie.DatasetSupervisor, start_options})
  end

  def ensure_stopped(dataset_id), do: stop_dataset_supervisor(dataset_id)

  def child_spec(args) do
    dataset = Keyword.fetch!(args, :dataset)

    super(args)
    |> Map.put(:id, name(dataset.id))
  end

  def start_link(opts) do
    dataset = Keyword.fetch!(opts, :dataset)
    Supervisor.start_link(__MODULE__, opts, name: name(dataset.id))
  end

  defp stop_dataset_supervisor(dataset_id) do
    name = name(dataset_id)

    case Process.whereis(name) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(Valkyrie.Dynamic.Supervisor, pid)
    end
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
    Supervisor.child_spec({Elsa.Supervisor, endpoints: elsa_brokers(), connection: producer, producer: [topic: topic]},
      id: :"#{dataset.id}_elsa_producer"
    )
  end

  defp broadway(dataset, input_topic, output_topic, producer) do
    config = [
      dataset: dataset,
      output: [
        connection: producer,
        topic: output_topic
      ],
      input: [
        connection: :"#{dataset.id}_elsa_consumer",
        endpoints: elsa_brokers(),
        group_consumer: [
          group: "valkyrie-#{input_topic}",
          topics: [input_topic],
          config: topic_subscriber_config()
        ]
      ]
    ]

    {Valkyrie.Broadway, config}
  end
end
