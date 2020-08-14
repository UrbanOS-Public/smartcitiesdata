defmodule DiscoveryStreams.Stream.SourceHandler do
  @moduledoc """
  Callbacks for handling data messages.
  See [Source.Handler](../../../../protocol_source/lib/source/handler.ex)
  for more.
  """
  use Source.Handler
  use Properties, otp_app: :discovery_streams
  require Logger

  alias DiscoveryStreamsWeb.Endpoint

  getter(:dlq, default: Dlq)

  def handle_message(message, context) do
    # load = context.assigns.load

    Logger.debug(fn ->
      "#{__MODULE__}: Broadcasting to broadcast: TODO"
    end)

    IO.inspect(context, label: "context")
    IO.inspect(message, label: "message")
    # case Brook.get(:discovery_streams, :streaming_datasets_by_id, channel) do
    #   {:ok, system_name} ->
    Endpoint.broadcast!("streaming:#{context.assigns.dataset.technical.systemName}", "update", message)

    #   _ ->
    #     nil
    # end

    Ok.ok(message)
  end

  def handle_batch(batch, context) do
    Logger.debug(fn -> "#{__MODULE__} handle_batch - #{inspect(context)} - #{inspect(batch)}" end)

    # unless context.assigns.load.destination.cache == 0 do
    #   Broadcast.Cache.add(context.assigns.cache, batch)
    # end

    :ok
  end

  def send_to_dlq(dead_letters, _context) do
    dlq().write(dead_letters)
    :ok
  end
end
