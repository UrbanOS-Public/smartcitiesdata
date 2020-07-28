defprotocol Destination do
  @moduledoc """
  Defines a protocol for data destinations -- where data is written or loaded into.
  """
  @spec start_link(t, Destination.Context.t()) :: GenServer.on_start()
  def start_link(t, context)

  @spec write(t, GenServer.server(), messages :: list(term)) :: :ok | {:error, term}
  def write(t, server, messages)

  @spec stop(t, GenServer.server()) :: :ok
  def stop(t, server)

  @spec delete(t) :: :ok | {:error, term}
  def delete(t)
end
