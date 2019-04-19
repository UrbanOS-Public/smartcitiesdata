defmodule Yeet do
  alias Yeet.KafkaHelper
  @moduledoc false

  def process_dead_letter(message, app_name, options \\ []) do
    dead_letter =
      message
      |> sanitize_message()
      |> format_message(app_name, options)

    KafkaHelper.produce(dead_letter)
  end

  def sanitize_message(message) do
    case Jason.encode(%{message: message}) do
      {:ok, _message} -> message
      {:error, _unencodable_message} -> inspect(message)
    end
  end

  def format_message(original_message, app_name, options \\ []) do
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
      app: app_name,
      original_message: original_message,
      stacktrace: stacktrace,
      exit_code: exit_code,
      error: error,
      reason: reason,
      timestamp: timestamp
    }
  end

  defp get_stacktrace(stacktrace) when is_list(stacktrace) do
    stacktrace
  end

  defp get_stacktrace({_, stacktrace}) when is_list(stacktrace) do
    stacktrace
  end
end
