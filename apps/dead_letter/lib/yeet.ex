defmodule Yeet do
  @moduledoc false

  def format_message(app_name, original_message, options \\ []) do
    stacktrace =
      case Keyword.get(options, :stacktrace) do
        nil -> nil
        e -> Exception.format_stacktrace(e)
      end

    exit =
      case Keyword.get(options, :exit) do
        nil -> nil
        e -> Exception.format_exit(e)
      end

    error = Keyword.get(options, :error)
    reason = Keyword.get(options, :reason)
    timestamp = Keyword.get(options, :timestamp, DateTime.utc_now())

    %{
      app: app_name,
      original_message: Jason.encode!(original_message),
      stacktrace: stacktrace,
      exit: exit,
      error: error,
      reason: reason,
      timestamp: timestamp
    }
  end
end
