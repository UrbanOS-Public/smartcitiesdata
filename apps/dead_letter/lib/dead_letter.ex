defmodule DeadLetter do
  @moduledoc """
  Provides functions and processes for sanitizing
  messages that are unable to be processed by a standard
  data processing pipeline and sending them to a configurable
  dead letter message queue service.
  """

  defdelegate start_link(opts), to: DeadLetter.Supervisor

  defdelegate child_spec(args), to: DeadLetter.Supervisor

  @doc """
  Given a message with a dataset id and app name, send a message to the dead letter queue that contains that message, along with additional metadata.
  """
  @spec process(String.t(), any(), String.t(), keyword()) :: :ok | {:error, any()}
  defdelegate process(dataset_id, message, app_name, options \\ []), to: DeadLetter.Server
end
