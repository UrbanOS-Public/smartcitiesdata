defmodule Forklift.Init do
  @moduledoc """
  Task to initialize forklift and start ingesting each previously recorded dataset
  """
  use Task, restart: :transient

  alias Forklift.MessageHandler

  @reader Application.get_env(:forklift, :data_reader)
  @topic_writer Application.get_env(:forklift, :topic_writer)

  def start_link(_opts) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run() do
    init_topic_writer()

    Forklift.Datasets.get_all!()
    |> Enum.map(&reader_init_args/1)
    |> Enum.each(fn args -> @reader.init(args) end)
  end

  defp init_topic_writer do
    case Application.get_env(:forklift, :output_topic) do
      nil ->
        []

      topic ->
        writer_init_args(:forklift, topic)
        |> @topic_writer.init()
    end
  end

  def writer_init_args(instance, topic) do
    [
      instance: instance,
      endpoints: Application.get_env(instance, :elsa_brokers),
      topic: topic,
      producer_name: Application.get_env(instance, :producer_name),
      retry_count: Application.get_env(instance, :retry_count),
      retry_delay: Application.get_env(instance, :retry_initial_delay)
    ]
  end

  defp reader_init_args(dataset) do
    [app: :forklift, handler: MessageHandler, dataset: dataset]
  end
end
