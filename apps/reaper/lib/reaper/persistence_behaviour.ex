defmodule Reaper.PersistenceBehaviour do
  @callback record_last_processed_index(any(), any()) :: :ok | {:error, any()}
  @callback get_last_processed_index(any()) :: integer()
  @callback remove_last_processed_index(any()) :: :ok | {:error, any()}
end