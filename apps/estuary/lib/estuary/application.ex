defmodule Estuary.Application do
  @moduledoc false
  use Application

  alias Estuary.Datasets.DatasetSchema
  alias Estuary.DataWriter

  import Estuary

  @reader Application.get_env(:estuary, :topic_reader)

  @spec start(any, any) :: {:error, any} | {:ok, pid}
  def start(_type, _args) do
    DatasetSchema.table_schema()
    |> DataWriter.init()

    reader_args()
    |> @reader.init()
    children = []
    opts = [strategy: :one_for_one, name: Estuary.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp reader_args() do
    [
      instance: instance_name(),
      connection: Application.get_env(:estuary, :connection),
      endpoints: Application.get_env(:estuary, :endpoints),
      topic: Application.get_env(:estuary, :topic),
      handler: Estuary.MessageHandler
    ]
  end
end
