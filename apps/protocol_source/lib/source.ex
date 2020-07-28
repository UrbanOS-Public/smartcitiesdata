defprotocol Source do
  @moduledoc """
  Defines a protocol for data sources -- where data is coming from.
  """
  @spec start_link(t, Source.Context.t()) :: GenServer.on_start()
  def start_link(t, context)

  @spec stop(t, GenServer.server()) :: :ok
  def stop(t, server)

  @spec delete(t) :: :ok | {:error, term}
  def delete(t)
end
