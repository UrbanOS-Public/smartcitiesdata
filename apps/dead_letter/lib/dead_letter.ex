defmodule DeadLetter do
  @moduledoc """
  Provides functions and processes for sanitizing
  messages that are unable to be processed by a standard
  data processing pipeline and sending them to a configurable
  dead letter message queue service.
  """

  @doc """
  Given a message with a list of dataset ids, ingestion id, and app name, send a message to the dead letter queue that contains that message, along with additional metadata.
  """
  @spec process(list(String.t()), String.t(), any(), String.t(), keyword()) :: :ok | {:error, any()}
  defdelegate process(dataset_ids, ingestion_id, message, app_name, options \\ []), to: DeadLetter.Server
end
