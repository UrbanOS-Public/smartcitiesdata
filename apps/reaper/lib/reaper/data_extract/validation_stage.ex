defmodule Reaper.DataExtract.ValidationStage do
  @moduledoc false
  use GenStage

  alias Reaper.{Cache, Persistence}

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  def init(args) do
    ingestion = Keyword.fetch!(args, :ingestion)

    state = %{
      cache: Keyword.fetch!(args, :cache),
      ingestion: ingestion,
      last_processed_index: Persistence.get_last_processed_index(ingestion.id)
    }

    {:producer_consumer, state}
  end

  def handle_events(incoming, _from, state) do
    outgoing =
      incoming
      |> Enum.reduce([], &handle_event(state, &1, &2))
      |> Enum.reverse()

    {:noreply, outgoing, state}
  end

  defp handle_event(state, {value, index} = message, acc) do
    with {:ok, _} <- check_cache(state, value),
         {:index_check, true} <- {:index_check, index > state.last_processed_index} do
      [message | acc]
    else
      {:error, reason} ->
        DeadLetter.process(state.ingestion.targetDatasets, state.ingestion.id, message, "reaper",
          reason: inspect(reason)
        )

        acc

      _duplicate_or_index_failure ->
        acc
    end
  end

  defp check_cache(state, value) do
    case state.ingestion.allow_duplicates do
      true -> {:ok, value}
      false -> Cache.mark_duplicates(state.cache, value)
    end
  end
end
