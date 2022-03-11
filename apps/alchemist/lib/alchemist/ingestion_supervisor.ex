defmodule Alchemist.IngestionSupervisor do
  @moduledoc """
  Supervisor for each ingestion that supervises the elsa producer and broadway pipeline.
  """
  use Supervisor
  use Properties, otp_app: :alchemist

  getter(:topic_subscriber_config, generic: true)
  getter(:elsa_brokers, generic: true)

  def name(id), do: :"#{id}_supervisor"

  def ensure_started(start_options) do
    ingestion = Keyword.fetch!(start_options, :ingestion)

    case get_ingestion_supervisor(ingestion.id) do
      nil ->
        {:ok, _pid} =
          DynamicSupervisor.start_child(Alchemist.Dynamic.Supervisor, {Alchemist.IngestionSupervisor, start_options})

      pid ->
        {:ok, pid}
    end
  end

  def ensure_stopped(ingestion_id), do: stop_ingestion_supervisor(ingestion_id)

  def is_started?(ingestion_id), do: get_ingestion_supervisor(ingestion_id) != nil

  def child_spec(args) do
    ingestion = Keyword.fetch!(args, :ingestion)

    super(args)
    |> Map.put(:id, name(ingestion.id))
  end

  def start_link(opts) do
    ingestion = Keyword.fetch!(opts, :ingestion)
    Supervisor.start_link(__MODULE__, opts, name: name(ingestion.id))
  end

  def get_ingestion_supervisor(ingestion_id), do: Process.whereis(name(ingestion_id))

  defp stop_ingestion_supervisor(ingestion_id) do
    name = name(ingestion_id)

    case Process.whereis(name) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(Alchemist.Dynamic.Supervisor, pid)
    end
  end

  @impl Supervisor
  def init(opts) do
    ingestion = Keyword.fetch!(opts, :ingestion)
    input_topic = Keyword.fetch!(opts, :input_topic)
    output_topic = Keyword.fetch!(opts, :output_topic)
    producer = :"#{ingestion.id}_producer"

    children = [
      elsa_producer(ingestion, output_topic, producer),
      broadway(ingestion, input_topic, output_topic, producer)
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  defp elsa_producer(ingestion, topic, producer) do
    Supervisor.child_spec({Elsa.Supervisor, endpoints: elsa_brokers(), connection: producer, producer: [topic: topic]},
      id: :"#{ingestion.id}_elsa_producer"
    )
  end

  defp broadway(ingestion, input_topic, output_topic, producer) do
    config = [
      ingestion: ingestion,
      output: [
        connection: producer,
        topic: output_topic
      ],
      input: [
        connection: :"#{ingestion.id}_elsa_consumer",
        endpoints: elsa_brokers(),
        group_consumer: [
          group: "alchemist-#{input_topic}",
          topics: [input_topic],
          config: topic_subscriber_config()
        ]
      ]
    ]

    {Alchemist.Broadway, config}
  end
end
