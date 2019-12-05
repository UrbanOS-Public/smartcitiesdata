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
    Supervisor.start_link(__MODULE__, opts, name: :"#{@name}_supervisor")
  end

  @impl Supervisor
  def init(opts) do
    topic = Keyword.fetch!(opts, :topic)

    elsa_config = [
      connection: @name,
      endpoints: Keyword.fetch!(opts, :endpoints),
      producer: [topic: topic]
    ]

    Process.put(:topic, topic)

    children = [
      {Elsa.Supervisor, elsa_config}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Sends a message to the dead letter topic
  """
  @impl DeadLetter.Carrier
  def send(message) do
    topic = get_topic(:"#{@name}_supervisor")
    Elsa.produce(@name, topic, {message.app, Jason.encode!(message)})
  rescue
    e -> Logger.error("Unable to dead-letter message: #{inspect(message)}\n\treason: #{inspect(e)}")
  end

  defp get_topic(name) do
    name
    |> Process.whereis()
    |> Process.info()
    |> get_in([:dictionary, :topic])
  end
end
