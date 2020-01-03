defmodule Estuary.DataReader do
  @moduledoc """
  Implementation of `Pipeline.Reader` for Estuary's edges.
  """

  import Estuary

  @behaviour Pipeline.Reader

  @topic_reader Application.get_env(:estuary, :topic_reader)
  @writer Application.get_env(:estuary, :table_writer)


  @impl Pipeline.Reader
  @doc """

  """

  def init(_opts \\ []) do
    # :ok =
    #   reader_args()
    #   |> IO.inspect()
    #   |> @reader.init()
    # @topic_reader.init(nil)

    # rescue
    #   e -> {:error, e, "Presto Error"}
  end

  @impl Pipeline.Reader
  @doc """

  """

  def terminate(_opts \\ []) do
    :ok
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
