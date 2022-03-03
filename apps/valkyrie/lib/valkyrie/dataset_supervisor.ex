defmodule Valkyrie.DatasetSupervisor do
  @moduledoc """
  Supervisor for each dataset that supervises the elsa producer and broadway pipeline.
  """
  use Supervisor
  use Properties, otp_app: :valkyrie

  getter(:topic_subscriber_config, generic: true)
  getter(:elsa_brokers, generic: true)

  @instance_name Valkyrie.instance_name()

  def name(id), do: :"#{id}_supervisor"

  def ensure_started(start_options) do
    dataset_id = Keyword.fetch!(start_options, :dataset_id)

    case get_dataset_supervisor(dataset_id) do
      nil ->
        {:ok, _pid} =
          DynamicSupervisor.start_child(Valkyrie.Dynamic.Supervisor, {Valkyrie.DatasetSupervisor, start_options})

      pid ->
        {:ok, pid}
    end
  end

  def ensure_stopped(dataset_id), do: stop_dataset_supervisor(dataset_id)

  def is_started?(dataset_id), do: get_dataset_supervisor(dataset_id) != nil

  def child_spec(args) do
    dataset_id = Keyword.fetch!(args, :dataset_id)

    super(args)
    |> Map.put(:id, name(dataset_id))
  end

  def start_link(opts) do
    dataset_id = Keyword.fetch!(opts, :dataset_id)
    Supervisor.start_link(__MODULE__, opts, name: name(dataset_id))
  end

  def get_dataset_supervisor(dataset_id), do: Process.whereis(name(dataset_id))

  defp stop_dataset_supervisor(dataset_id) do
    name = name(dataset_id)

    case Process.whereis(name) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(Valkyrie.Dynamic.Supervisor, pid)
    end
  end

  @impl Supervisor
  def init(opts) do
    dataset_id = Keyword.fetch!(opts, :dataset_id)
    input_topic = Keyword.fetch!(opts, :input_topic)
    output_topic = Keyword.fetch!(opts, :output_topic)
    producer = :"#{dataset_id}_producer"

    children = [
      elsa_producer(dataset_id, output_topic, producer),
      broadway(dataset_id, input_topic, output_topic, producer)
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  defp elsa_producer(dataset_id, topic, producer) do
    Supervisor.child_spec({Elsa.Supervisor, endpoints: elsa_brokers(), connection: producer, producer: [topic: topic]},
      id: :"#{dataset_id}_elsa_producer"
    )
  end

  defp broadway(dataset_id, input_topic, output_topic, producer) do
    dataset = Brook.get(@instance_name, :datasets, dataset_id)

    config = [
      dataset: dataset,
      output: [
        connection: producer,
        topic: output_topic
      ],
      input: [
        connection: :"#{dataset_id}_elsa_consumer",
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
