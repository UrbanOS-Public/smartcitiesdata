defmodule Yeet do
  alias Yeet.KafkaHelper

  @moduledoc """
  Format, enrich and send a message to a dead letter queue.
  """

  require Logger

  @doc """
  Given a message with a dataset id and app name, send a message to the dead letter queue that contains that message, along with additional metadata.
  """
  @spec process_dead_letter(String.t(), any(), atom(), keyword()) :: :ok | {:error, any()}
  def process_dead_letter(dataset_id, message, app_name, options \\ []) do
    dead_letter =
      message
      |> sanitize_message()
      |> format_message(dataset_id, app_name, options)

    Logger.info(fn -> "Yeeting: #{inspect(dead_letter)}" end)
    KafkaHelper.produce(dead_letter)
  end

  @doc """
  Checks that the message can be encoded to json. If it cannot, it transforms the message into an encodable format.
  """
  def sanitize_message(message) do
    case Jason.encode(%{message: message}) do
      {:ok, _message} -> message
      {:error, _unencodable_message} -> inspect(message)
    end
  end

  @doc """
    Takes a message and formats the fields so that they can properly be encoded as json. It also enriches the message with a stack trace and timestamp.
  """
  @spec format_message(any(), String.t(), atom(), keyword()) :: map()
  def format_message(original_message, dataset_id, app_name, options \\ []) do
    stacktrace =
      options
      |> Keyword.get(:stacktrace, Process.info(self(), :current_stacktrace))
      |> get_stacktrace()
      |> Exception.format_stacktrace()

    exit_code =
      case Keyword.get(options, :exit_code) do
        nil -> nil
        e -> Exception.format_exit(e)
      end

    error = Keyword.get(options, :error)
    reason = Keyword.get(options, :reason)
    timestamp = Keyword.get(options, :timestamp, DateTime.utc_now())

    %{
      dataset_id: dataset_id,
      app: app_name,
      original_message: original_message,
      stacktrace: stacktrace,
      exit_code: exit_code,
      error: format_exception(error),
      reason: format_exception(reason),
      timestamp: timestamp
    }
  end

  defp format_exception(exception) do
    case Exception.exception?(exception) do
      true -> Exception.format(:error, exception)
      false -> exception
    end
  end

  defp get_stacktrace(stacktrace) when is_list(stacktrace) do
    stacktrace
  end

  defp get_stacktrace({_, stacktrace}) when is_list(stacktrace) do
    stacktrace
  end
end
