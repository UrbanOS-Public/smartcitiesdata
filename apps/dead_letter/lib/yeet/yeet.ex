defmodule Yeet do
  alias Yeet.KafkaHelper
  @moduledoc false

  def process_dead_letter(message, app_name, options \\ []) do
    dead_letter = format_message(message, app_name, options)
    KafkaHelper.produce(dead_letter)
  end

  def format_message(original_message, app_name, options \\ []) do
    stacktrace =
      case Keyword.get(options, :stacktrace) do
        nil -> nil
        {_, stacktrace} -> Exception.format_stacktrace(stacktrace)
      end

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
end
