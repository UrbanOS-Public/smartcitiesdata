defmodule Forklift.IngestionTimer do
  def start(dataset, ingestion_id, extract_id, extract_time, timeout_timer \\ 240000) do
    Task.async(fn -> timer(dataset, ingestion_id, extract_id, extract_time, timeout_timer) end)
  end

  defp timer(dataset, ingestion_id, extract_id, extract_time, timeout_timer) do
    IO.inspect(timeout_timer, label: "remaining")
    if timeout_timer <= 0 do
      Forklift.IngestionProgress.complete_extract(extract_id)
      Forklift.Jobs.DataMigration.compact(dataset, ingestion_id, extract_time)
      IO.inspect("completed via timeout")
    else
      :timer.sleep(1000)
      if not Forklift.IngestionProgress.is_extract_done(extract_id) do
        timer(dataset, ingestion_id, extract_id, extract_time, timeout_timer - 1000)
      end
    end
  end
end
