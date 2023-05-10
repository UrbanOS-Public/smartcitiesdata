defmodule Forklift.IngestionTimer do
  require Logger

  @spec compact_if_not_finished(SmartCity.Dataset.t(), String.t(), String.t(), String.t()) ::
          nil | {:abort, any} | {:error, any} | {:ok, any}
  def compact_if_not_finished(dataset, ingestion_id, extract_id, extract_time) do
    if not Forklift.IngestionProgress.is_extract_done(extract_id) do
      Logger.info("Ingestion: #{ingestion_id} Dataset: #{dataset.id} - Compacting when not finished?")
      Forklift.IngestionProgress.complete_extract(extract_id)
      Forklift.Jobs.DataMigration.compact(dataset, ingestion_id, extract_time)
    end
  end
end
