defmodule Estuary.DataReader do
  @moduledoc """
  Implementation of `Pipeline.Reader` for Estuary's edges.
  """
  use Properties, otp_app: :estuary

  import Estuary

  @behaviour Pipeline.Reader

  getter(:topic_reader, generic: true)
  getter(:connection, generic: true)
  getter(:endpoints, generic: true)
  getter(:topic, generic: true)
  getter(:topic_subscriber_config, generic: true, default: [])

  @impl Pipeline.Reader
  def init(_opts \\ []) do
    :ok = topic_reader().init(reader_args())
  end

  @impl Pipeline.Reader
  def terminate(_opts \\ []) do
    :ok = topic_reader().terminate(reader_args())
  end

  defp reader_args do
    [
      instance: instance_name(),
      connection: connection(),
      endpoints: endpoints(),
      topic: topic(),
      handler: Estuary.MessageHandler,
      topic_subscriber_config: topic_subscriber_config()
    ]
  end
end
