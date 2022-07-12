defmodule DeadLetter.Server do
  @moduledoc """
  Parse dead letter messages, sanitize errors and stack traces to
  an encodable format and dispatch to the appropriate message queue
  driver as defined in the config.
  """

  defimpl Jason.Encoder, for: Tuple do
    def encode(value, opts) do
      value
      |> Tuple.to_list()
      |> Jason.Encode.list(opts)
    end
  end

  use GenServer
  require Logger

  @doc """
  Start a DeadLetter server and link it to the current process.
  """
  @spec start_link(term()) :: {:ok, pid()}
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Initialize the DeadLetter server from configuration.
  """
  def init(config) do
    {:ok, config}
  end

  def handle_cast({:process, message}, state) do
    apply(state.module, :send, [message])
    {:noreply, state}
  end

  @doc """
  Given a message with a dataset id, ingestion id, and app name, send a message
  to the dead letter queue that contains that message, along with additional
  metadata.
  """
  @spec process(String.t(), String.t(), any(), String.t(), keyword()) :: :ok | {:error, any()}
  def process(dataset_id, ingestion_id, message, app_name, options \\ []) do
    dead_letter =
      message
      |> sanitize_message()
      |> format_message(dataset_id, ingestion_id, app_name, options)

    Logger.info(fn -> "Enqueueing dead letter: #{inspect(dead_letter)}" end)

    GenServer.cast(__MODULE__, {:process, dead_letter})
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
  @spec format_message(any(), String.t(), String.t(), String.t(), keyword()) :: map()
  def format_message(original_message, dataset_id, ingestion_id, app_name, options \\ []) do
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

    add_dead_letter_count(dataset_id, reason)

    %{
      dataset_id: dataset_id,
      ingestion_id: ingestion_id,
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

  defp add_dead_letter_count(dataset_id, reason) do
    [
      dataset_id: dataset_id,
      reason: Kernel.inspect(reason)
    ]
    |> TelemetryEvent.add_event_metrics([:dead_letters_handled])
  rescue
    error ->
      Logger.error("Unable to update the metrics: #{error}")
  end
end
