defmodule Flair.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Flair.Flow, []},
      kafka_ex()
    ]

    opts = [strategy: :one_for_one, name: Flair.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def kafka_ex do
    consumer_group_opts = []

    gen_consumer_impl = Flair.MessageProcessor
    consumer_group_name = "flair-consumer-group"
    topic_names = ["streaming-validated"]

    Supervisor.Spec.supervisor(KafkaEx.ConsumerGroup, [
      gen_consumer_impl,
      consumer_group_name,
      topic_names,
      consumer_group_opts
    ])
  end
end
