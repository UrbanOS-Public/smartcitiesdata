defmodule Forklift.IngestionProgress do
  @spec new_messages(Integer.t(), String.t(), Integer.t()) :: :in_progress | :ingestion_complete
  def new_messages(count, ingestion_id, extract_time) do
    extract_id = get_extract_id(ingestion_id, extract_time)

    increment_ingestion_count(extract_id, count)

    case(is_extract_done(extract_id)) do
      false ->
        :in_progress

      true ->
        complete_extract(extract_id)
    end
  end

  @spec store_target(SmartCity.Dataset.t(), Integer.t(), String.t(), Integer.t()) :: :in_progress | :ingestion_complete
  def store_target(dataset, target, ingestion_id, extract_time) do
    extract_id = get_extract_id(ingestion_id, extract_time)

    timer = :timer.apply_after(240000, Forklift.IngestionTimer, :compact_if_not_finished, [dataset, ingestion_id, extract_id, extract_time])

    set_extract_target(extract_id, target)

    case(is_extract_done(extract_id)) do
      false ->
        :in_progress

      true ->
        complete_extract(extract_id, timer)
    end
  end

  @spec increment_ingestion_count(String.t(), Integer.t()) :: integer()
  defp increment_ingestion_count(extract_id, count) do
    Redix.command!(:redix, ["INCRBY", get_count_key(extract_id), count])
  end

  @spec set_extract_target(String.t(), Integer.t()) :: integer()
  defp set_extract_target(extract_id, target) do
    Redix.command!(:redix, ["SET", get_target_key(extract_id), target])
  end

  @spec is_extract_done(String.t()) :: boolean()
  def is_extract_done(extract_id) do
    target = Redix.command!(:redix, ["GET", get_target_key(extract_id)])
    current = Redix.command!(:redix, ["GET", get_count_key(extract_id)])

    case target && current do
      nil ->
        false

      _ ->
        String.to_integer(current) >= String.to_integer(target)
    end
  end

  defp get_count_key(extract_id) do
    extract_id <> "_count"
  end

  defp get_target_key(extract_id) do
    extract_id <> "_target"
  end

  @spec complete_extract(binary, any) :: :ingestion_complete
  def complete_extract(extract_id, timer \\ nil) do
    Redix.command!(:redix, ["GETDEL", get_count_key(extract_id)])
    Redix.command!(:redix, ["GETDEL", get_target_key(extract_id)])

    if timer != nil do
      :timer.cancel(timer)
    end
    :ingestion_complete
  end

  @spec get_extract_id(String.t(), Integer.t()) :: String.t()
  defp get_extract_id(ingestion_id, extract_time) do
    ingestion_id <> "_" <> (extract_time |> Integer.to_string())
  end
end
