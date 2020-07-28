defmodule Source.Message do
  @moduledoc """
  Encapsulates data through source handler functions.
  """
  @type t :: %__MODULE__{}
  defstruct [:original, :value, :error, :stacktrace]
end

defmodule Source.Handler do
  @moduledoc """
  Behaviour describing functions necessary to handle single messages,
  message batches, and writing errant messages to a DLQ.
  """
  @type impl :: module

  @callback handle_message(map, Source.Context.t()) :: {:ok, map} | {:error, term}
  @callback handle_batch(list(map), Source.Context.t()) :: :ok
  @callback send_to_dlq(list(DeadLetter.t()), Source.Context.t()) :: :ok
  @callback shutdown(Source.Context.t()) :: :ok

  defmacro __using__(_opts) do
    quote do
      @behaviour Source.Handler

      def handle_message(message, _), do: Ok.ok(message)
      def shutdown(_context), do: :ok
      defoverridable Source.Handler
    end
  end

  @spec inject_messages(list(Source.Message.t()), Source.Context.t()) :: :ok
  def inject_messages(messages, context) do
    messages
    |> Enum.map(&decode(&1, context))
    |> Enum.map(&do_message(&1, context))
    |> Enum.group_by(fn
      %{error: nil} -> :ok
      _ -> :error
    end)
    |> Enum.each(&do_batch(&1, context))
  end

  defp decode(%{value: value} = msg, %{decode_json: true}) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, decoded_value} -> %{msg | value: decoded_value}
      {:error, reason} -> %{msg | error: reason}
    end
  end

  defp decode(msg, _), do: msg

  defp do_message(%{error: nil, value: value} = msg, context) do
    case context.handler.handle_message(value, context) do
      {:ok, new_value} -> %{msg | value: new_value}
      {:error, reason} -> %{msg | error: reason}
    end
  catch
    _, reason ->
      %{msg | error: reason, stacktrace: __STACKTRACE__}
  end

  defp do_message(msg, _), do: msg

  defp do_batch({:ok, messages}, context) do
    messages
    |> Enum.map(&Map.get(&1, :value))
    |> context.handler.handle_batch(context)
  end

  defp do_batch({:error, messages}, context) do
    messages
    |> Enum.map(&to_dead_letter(context, &1))
    |> context.handler.send_to_dlq(context)
  end

  defp to_dead_letter(context, msg) do
    DeadLetter.new(
      app_name: to_string(context.app_name),
      dataset_id: context.dataset_id,
      subset_id: context.subset_id,
      original_message: msg.original,
      reason: msg.error,
      stacktrace: msg.stacktrace
    )
  end
end
