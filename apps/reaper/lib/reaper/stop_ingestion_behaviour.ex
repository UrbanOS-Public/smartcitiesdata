defmodule Reaper.StopIngestionBehaviour do
  @callback delete_quantum_job(String.t()) :: :ok | :error
  @callback stop_horde_and_cache(String.t()) :: :ok | :error
end