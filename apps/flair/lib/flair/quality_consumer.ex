defmodule Flair.QualityConsumer do
  @moduledoc """
  Consumer is called at the end of a flow; it converts events and then passess them to presto client to be persisted.
  """

  use GenStage

  alias Flair.PrestoClient

  def start_link(name, args \\ nil) do
    GenStage.start_link(__MODULE__, args, name: name)
  end

  def init(_args) do
    {:consumer, :any}
  end

  def handle_events(events, _from, state) do
    events
    |> convert_events()
    |> PrestoClient.generate_statement_from_events()
    |> PrestoClient.execute()

    {:noreply, [], state}
  end

  defp convert_events(events) do
    events
    |> Enum.map(fn {_id, event} -> event end)
    |> List.flatten()
  end
end
