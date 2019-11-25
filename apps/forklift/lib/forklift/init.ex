defmodule Forklift.Init do
  @moduledoc """
  Task to initialize forklift and start ingesting each previously recorded dataset
  """
  use GenServer

  alias Forklift.MessageHandler

  @name :forklift_init_server
  @reader Application.get_env(:forklift, :data_reader)

  def start_link(opts) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def init(_) do
    with :ok <- Forklift.DataWriter.bootstrap(),
         :ok <- init_readers(),
         pid <- Process.whereis(Pipeline.DynamicSupervisor) do
      Process.monitor(pid)
      {:ok, %{pipeline: pid}}
    end
  end

  def handle_info({:DOWN, _, _, down, _}, %{pipeline: pid}) when pid == down do
    :ok = init_readers()
    {:noreply, %{pipeline: Process.whereis(Pipeline.DynamicSupervisor)}}
  end

  defp init_readers do
    Forklift.Datasets.get_all!()
    |> Enum.map(&reader_init_args/1)
    |> Enum.map(&initialize/1)
    |> validate_inits()
  end

  defp reader_init_args(dataset) do
    [
      instance: Forklift.instance_name(),
      dataset: dataset,
      endpoints: Application.get_env(:forklift, :elsa_brokers),
      handler: MessageHandler,
      handler_init_args: [dataset: dataset],
      input_topic_prefix: Application.get_env(:forklift, :input_topic_prefix),
      topic_subscriber_config: Application.get_env(:forklift, :topic_subscriber_config)
    ]
  end

  defp initialize(args) do
    Process.sleep(250)
    @reader.init(args)
  end

  defp validate_inits(results) do
    case Enum.reject(results, fn res -> res == :ok end) do
      [] -> :ok
      [error | _] -> {:error, error}
    end
  end
end
