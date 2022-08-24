defmodule Forklift.IngestionProgress do
  @spec new_message(String.t()) :: :in_progress | :ingestion_complete
  def new_message(ingestion_id) do
    msgs_received = increment_ingestion_count(ingestion_id)

    case(is_ingestion_done(msgs_received, ingestion_id)) do
      false ->
        :in_progress

      true ->
        complete_ingestion(ingestion_id)
    end
  end

  @spec increment_ingestion_count(String.t()) :: integer()
  defp increment_ingestion_count(ingestion_id) do
    Redix.command!(:redix, ["INCR", get_count_key(ingestion_id)])
  end

  @spec is_ingestion_done(Integer.t(), String.t()) :: boolean()
  defp is_ingestion_done(msgs_received, ingestion_id) do
    case Redix.command!(:redix, ["GET", get_target_key(ingestion_id)]) do
      nil ->
        false

      target ->
        msgs_received >= String.to_integer(target)
    end
  end

  defp get_count_key(ingestion_id) do
    ingestion_id <> "_count"
  end

  defp get_target_key(ingestion_id) do
    ingestion_id <> "_target"
  end

  defp complete_ingestion(ingestion_id) do
    Redix.command!(:redix, ["GETDEL", get_count_key(ingestion_id)])
    Redix.command!(:redix, ["GETDEL", get_target_key(ingestion_id)])
    :ingestion_complete
  end
end
