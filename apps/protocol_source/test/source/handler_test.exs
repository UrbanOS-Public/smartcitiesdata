defmodule Source.HandlerTest do
  use ExUnit.Case

  defmodule TestHandler do
    use Source.Handler

    def handle_message(%{"raise" => reason}, _context) do
      raise reason
    end

    def handle_message(%{"error" => reason}, _context) do
      {:error, reason}
    end

    def handle_message(message, context) do
      send(context.assigns.test, {:handle_message, message})
      {:ok, message}
    end

    def handle_batch(batch, context) do
      send(context.assigns.test, {:handle_batch, batch})
      :ok
    end

    def send_to_dlq(dead_letters, context) do
      send(context.assigns.test, {:dlq, dead_letters})
      :ok
    end
  end

  setup do
    context = %Source.Context{
      handler: TestHandler,
      app_name: "testing",
      dataset_id: "ds1",
      subset_id: "sb1",
      assigns: %{test: self()}
    }

    [context: context]
  end

  test "messages are decoded and passed to handle_message and handle_batch", %{context: context} do
    messages = [
      %{"name" => "joe", "age" => 1},
      %{"name" => "bob", "age" => 2}
    ]

    assert :ok = Source.Handler.inject_messages(Enum.map(messages, &m/1), context)

    Enum.each(messages, fn message ->
      assert_received {:handle_message, ^message}
    end)

    assert_received {:handle_batch, ^messages}
  end

  test "will send  error messages to dlq", %{context: context} do
    message1 = %{"name" => "joe"}
    message2 = "{\"one:}"
    message3 = %{"name" => "bob"}
    message4 = %{"error" => "returned error"}
    message5 = %{"name" => "pete"}
    message6 = %{"raise" => "raised error"}

    messages = [
      m(message1),
      m(message2),
      m(message3),
      m(message4),
      m(message5),
      m(message6)
    ]

    assert :ok = Source.Handler.inject_messages(messages, context)

    assert_received {:handle_message, ^message1}
    assert_received {:handle_message, ^message3}
    assert_received {:handle_message, ^message5}
    assert_received {:handle_batch, [^message1, ^message3, ^message5]}

    assert_received {:dlq, [dead_letter2, dead_letter4, dead_letter6]}

    {:error, reason} = Jason.decode(message2)

    assert dead_letter2.app_name == context.app_name
    assert dead_letter2.dataset_id == context.dataset_id
    assert dead_letter2.subset_id == context.subset_id
    assert dead_letter2.reason == Exception.format(:error, reason)
    assert dead_letter2.original_message == message2

    assert dead_letter4.app_name == context.app_name
    assert dead_letter4.dataset_id == context.dataset_id
    assert dead_letter4.subset_id == context.subset_id
    assert dead_letter4.reason == ~s|** (ErlangError) Erlang error: "returned error"|
    assert dead_letter4.original_message == Jason.encode!(message4)

    assert dead_letter6.app_name == context.app_name
    assert dead_letter6.dataset_id == context.dataset_id
    assert dead_letter6.subset_id == context.subset_id
    assert dead_letter6.reason == ~s|** (RuntimeError) raised error|
    assert dead_letter6.original_message == Jason.encode!(message6)
  end

  defp m(opts) when is_list(opts) do
    %Source.Message{
      original: Keyword.fetch!(opts, :original) |> encode(),
      value: Keyword.fetch!(opts, :value) |> encode()
    }
  end

  defp m(value) do
    m(original: value, value: value)
  end

  defp encode(value) when is_binary(value), do: value
  defp encode(term), do: Jason.encode!(term)
end
