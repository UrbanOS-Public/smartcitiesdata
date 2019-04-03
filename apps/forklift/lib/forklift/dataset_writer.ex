defmodule Forklift.DatasetWriter do
  @moduledoc false

  alias Forklift.{DataBuffer, PersistenceClient}

  def perform(dataset_id) do
    pending_entries = DataBuffer.get_pending_data(dataset_id)
    payloads = Enum.map(pending_entries, fn %{data: data} -> data.payload end)

    PersistenceClient.upload_data(dataset_id, payloads)
    DataBuffer.mark_complete(dataset_id, pending_entries)
    DataBuffer.cleanup_dataset(dataset_id, pending_entries)
  end
end
