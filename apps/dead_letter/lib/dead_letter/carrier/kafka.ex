defmodule DeadLetter.Carrier.Kafka do
  @moduledoc """
  Implements the `DeadLetter.Carrier` behaviour for
  Kafka and uses the Elsa client to create a persistent
  producer client and send message to the Kafka-based queue.
  """
  require Logger
  use Supervisor
  @behaviour DeadLetter.Carrier
  @name :dead_letter_carrier

  @doc """
  Start the Kafka driver and link to the calling process.
  """
  @impl DeadLetter.Carrier
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl Supervisor
  def init(opts) do
    topic = Keyword.fetch!(opts, :topic)

    elsa_producer_config = [
      name: @name,
      endpoints: Keyword.fetch!(opts, :endpoints),
      topic: topic
    ]

    Process.put(:topic, topic)

    children = [
      {Elsa.Producer.Supervisor, elsa_producer_config}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Sends a message to the dead letter topic
  """
  @impl DeadLetter.Carrier
  def send(message) do
    Elsa.Producer.produce_sync(Process.get(:topic), {message.app, Jason.encode!(message)}, name: @name)
  rescue
    e -> Logger.error("Unable to dead-letter message: #{inspect(message)}\n\treason: #{inspect(e)}")
  end
end
