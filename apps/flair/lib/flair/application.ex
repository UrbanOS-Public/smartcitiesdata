defmodule Flair.Application do
  @moduledoc """
  Flair starts flows for both quality and duration, as well as a connection to kafka.
  """

  use Application

  @consumer_group_name "flair-consumer-group"
  @gen_consumer_impl Flair.MessageProcessor

  def start(_type, _args) do
    children = [
      {Flair.DurationsFlow, []},
      {Flair.QualityFlow, []},
      kafka_ex()
    ]

    opts = [strategy: :one_for_one, name: Flair.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def kafka_ex do
    consumer_group_opts = []
    topics = [Application.get_env(:flair, :data_topic)]

    %{
      id: KafkaEx.ConsumerGroup,
      start:
        {KafkaEx.ConsumerGroup, :start_link,
         [
           @gen_consumer_impl,
           @consumer_group_name,
           topics,
           consumer_group_opts
         ]},
      type: :supervisor
    }
  end
end
