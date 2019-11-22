defmodule Forklift.Init do
  @moduledoc """
  Task to initialize forklift and start ingesting each previously recorded dataset
  """
  use Task, restart: :transient

  alias Forklift.MessageHandler
  import Forklift

  @reader Application.get_env(:forklift, :data_reader)

  def start_link(_opts) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run() do
    Forklift.DataWriter.bootstrap()

    Forklift.Datasets.get_all!()
    |> Enum.map(&reader_init_args/1)
    |> Enum.each(fn args ->
      @reader.init(args)
      Process.sleep(250)
    end)
  end

  defp reader_init_args(dataset) do
    [
      instance: instance_name(),
      dataset: dataset,
      endpoints: Application.get_env(:forklift, :elsa_brokers),
      handler: MessageHandler,
      handler_init_args: [dataset: dataset],
      input_topic_prefix: Application.get_env(:forklift, :input_topic_prefix),
      topic_subscriber_config: Application.get_env(:forklift, :topic_subscriber_config)
    ]
  end
end
