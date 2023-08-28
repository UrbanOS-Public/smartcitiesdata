defmodule Reaper.DataExtract.SchemaStage do
  @moduledoc false
  use GenStage

  import SmartCity.Data, only: [end_of_data: 0]

  alias Reaper.DataExtract.SchemaFiller

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  def init(args) do
    state = %{
      ingestion: Keyword.fetch!(args, :ingestion)
    }

    {:producer_consumer, state}
  end

  def handle_events(incoming, _from, state) do
    outgoing = Enum.map(incoming, &handle_event(state, &1))

    {:noreply, outgoing, state}
  end

  defp handle_event(state, {payload, number} = msg) when payload == end_of_data() do
    msg
  end

  defp handle_event(state, {payload, number}) do
    {SchemaFiller.fill(state.ingestion.schema, payload), number}
  end
end
