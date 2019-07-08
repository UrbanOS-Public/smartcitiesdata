defmodule Reaper.DataFeed.SchemaStage do
  @moduledoc false
  use GenStage

  alias Reaper.DataFeed.SchemaFiller

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  def init(args) do
    state = %{
      config: Keyword.fetch!(args, :config)
    }

    {:producer_consumer, state}
  end

  def handle_events(incoming, _from, state) do
    outgoing = Enum.map(incoming, &handle_event(state, &1))

    {:noreply, outgoing, state}
  end

  defp handle_event(state, {payload, number}) do
    {SchemaFiller.fill(state.config.schema, payload), number}
  end
end
