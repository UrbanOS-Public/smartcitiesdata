defmodule DeadLetter do
  @moduledoc """
  Structure around errors in the data processing pipeline. `DeadLetter`
  objects should be written to the dead-letter-queue through `dlq`.

  ## Configuration

  * `dataset_id` - Required.
  * `subset_id` - Required.
  * `app_name` - Required. Atom or string name for application that produced the error.
  * `original_message` - Original message that caused the error.
  * `stacktrace` - Stacktrace for the error.
  * `reason` - Reason for the error. This is usually taken from an `{:error, reason}` tuple.
  """
  @type t :: %__MODULE__{
          version: integer,
          dataset_id: String.t(),
          subset_id: String.t(),
          original_message: term,
          app_name: String.Chars.t(),
          stacktrace: list,
          reason: Exception.t() | String.Chars.t(),
          timestamp: DateTime.t()
        }

  @derive Jason.Encoder
  defstruct version: 1,
            dataset_id: nil,
            subset_id: nil,
            original_message: nil,
            app_name: nil,
            stacktrace: [],
            reason: nil,
            timestamp: nil

  @spec new(keyword) :: t
  def new(values) do
    reason = Keyword.get(values, :reason, nil)
    stacktrace = Keyword.get(values, :stacktrace, [])

    struct_values =
      values
      |> Keyword.update(:app_name, "", &to_string/1)
      |> Keyword.update(:original_message, "", &sanitize_message/1)
      |> Keyword.update(:reason, "", &format_reason/1)
      |> Keyword.put(:stacktrace, format_stacktrace(stacktrace, reason))
      |> Keyword.put_new(:timestamp, DateTime.utc_now())

    struct(__MODULE__, struct_values)
  end

  defp format_reason({:failed, reason}) do
    reason = Exception.normalize(:error, reason)
    Exception.format(:error, reason)
  end

  defp format_reason({kind, reason, _stacktrace}) do
    reason = Exception.normalize(kind, reason)
    Exception.format(kind, reason)
  end

  defp format_reason(reason) when reason != nil do
    reason = Exception.normalize(:error, reason)
    Exception.format(:error, reason)
  end

  defp format_reason(nil), do: ""

  defp format_stacktrace(stacktrace, _) when stacktrace != nil and stacktrace != [] do
    Exception.format_stacktrace(stacktrace)
  end

  defp format_stacktrace(_, {_kind, _reason, stacktrace}) do
    Exception.format_stacktrace(stacktrace)
  end

  defp format_stacktrace(_, _) do
    {:current_stacktrace, trace} = Process.info(self(), :current_stacktrace)
    Exception.format_stacktrace(trace)
  end

  defp sanitize_message(message) do
    case Jason.encode(message) do
      {:ok, _} -> message
      {:error, _} -> inspect(message)
    end
  end
end
