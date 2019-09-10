defmodule Forklift.Datasets.DatasetSupervisor do
  @moduledoc """
  Supervisor for each schema that supervises the elsa consumer
  """
  use Supervisor
  alias Forklift.Datasets.DatasetSchema

  def name(%DatasetSchema{} = schema) do
    :"#{schema.id}_supervisor"
  end

  def child_spec(args) do
    schema = Keyword.fetch!(args, :schema)

    args
    |> super()
    |> Map.put(:id, name(schema))
  end

  def start_link(opts) do
    schema = Keyword.fetch!(opts, :schema)
    Supervisor.start_link(__MODULE__, opts, name: name(schema))
  end

  @impl Supervisor
  def init(opts) do
    schema = Keyword.fetch!(opts, :schema)
    input_topic = Keyword.fetch!(opts, :input_topic)

    children = [
      elsa_consumer(schema, input_topic)
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  defp elsa_consumer(%DatasetSchema{} = schema, topic) do
    start_options = [
      brokers: Application.get_env(:forklift, :elsa_brokers),
      name: :"input-#{topic}",
      group: "forklift-#{topic}",
      topics: [topic],
      handler: Forklift.Messages.MessageHandler,
      handler_init_args: [schema: schema],
      config: Application.get_env(:forklift, :topic_subscriber_config, [])
    ]

    Supervisor.child_spec({Elsa.Group.Supervisor, start_options}, id: :"#{schema.id}_elsa_consumer")
  end
end
