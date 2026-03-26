defmodule Reaper.ManualTrigger do
  @moduledoc """
  Provides a function to manually trigger a Reaper ingestion.
  
  For Vault token debugging, see Reaper.VaultTokenDebugger.
  """

  alias Reaper.Collections.Extractions
  alias Reaper.Horde.Supervisor

  def trigger_ingestion(ingestion_id) do
    IO.puts("Triggering ingestion with ID: #{ingestion_id}")

    case Extractions.get_ingestion!(ingestion_id) do
      nil ->
        IO.puts("Ingestion with ID '#{ingestion_id}' not found.")

      ingestion ->
        IO.puts("Found ingestion: #{inspect(ingestion)}")
        Supervisor.start_data_extract(ingestion)
        IO.puts("Ingestion started.")
    end
  end
end
