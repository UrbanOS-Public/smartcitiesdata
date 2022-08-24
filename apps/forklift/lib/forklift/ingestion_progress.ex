defmodule Forklift.IngestionProgress do
  @spec new_message(String.t()) :: :in_progress | :ingestion_complete
  def new_message(ingestion_id) do
    increment_ingestion_count(ingestion_id)

    case(is_ingestion_done(ingestion_id)) do
      false ->
        :in_progress

      true ->
        complete_ingestion(ingestion_id)
    end
  end

  @spec store_target(String.t(), Integer.t()) :: :in_progress | :ingestion_complete
  def store_target(ingestion_id, target) do
    set_ingestion_target(ingestion_id, target)

    case(is_ingestion_done(ingestion_id)) do
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

  @spec set_ingestion_target(String.t(), Integer.t()) :: integer()
  defp set_ingestion_target(ingestion_id, target) do
    Redix.command!(:redix, ["SET", get_target_key(ingestion_id), target])
  end

  @spec is_ingestion_done(String.t()) :: boolean()
  defp is_ingestion_done(ingestion_id) do
    target = Redix.command!(:redix, ["GET", get_target_key(ingestion_id)])
    current = Redix.command!(:redix, ["GET", get_count_key(ingestion_id)])

    case target && current do
      nil ->
        false

      _ ->
        String.to_integer(current) >= String.to_integer(target)
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
