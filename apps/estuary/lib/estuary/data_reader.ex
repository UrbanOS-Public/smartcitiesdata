defmodule Estuary.DataReader do
  @moduledoc """
  Implementation of `Pipeline.Reader` for Estuary's edges.
  """

  import Estuary

  @behaviour Pipeline.Reader

  @topic_reader Application.get_env(:estuary, :topic_reader)

  @impl Pipeline.Reader
  def init(_opts \\ []) do
    :ok = @topic_reader.init(reader_args())
  end

  @impl Pipeline.Reader
  def terminate(_opts \\ []) do
    :ok = @topic_reader.terminate(reader_args())
  end

  defp reader_args do
    [
      instance: instance_name(),
      connection: Application.get_env(:estuary, :connection),
      endpoints: Application.get_env(:estuary, :endpoints),
      topic: Application.get_env(:estuary, :topic),
      handler: Estuary.MessageHandler
    ]
  end
end
