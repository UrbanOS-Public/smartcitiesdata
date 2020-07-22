defmodule Source.Fake do
  @moduledoc """
  `Source.t()` impl for testing.
  """
  @derive Jason.Encoder
  defstruct [:id]

  def new!(opts \\ []) do
    case :ets.whereis(__MODULE__) do
      :undefined -> :ets.new(__MODULE__, [:named_table, :public])
      _ -> :ok
    end

    id = id()
    {:ok, agent} = Agent.start(fn -> Map.new(opts) end)
    :ets.insert(__MODULE__, {id, self(), nil, agent})

    %__MODULE__{
      id: id
    }
  end

  def inject_messages(t, messages) do
    context = :ets.lookup_element(__MODULE__, t.id, 3)

    messages
    |> Enum.map(fn msg ->
      encoded = Jason.encode!(msg)
      %Source.Message{original: encoded, value: encoded}
    end)
    |> Source.Handler.inject_messages(context)
  end

  def stop(t, reason \\ :shutdown) do
    agent = :ets.lookup_element(Source.Fake, t.id, 4)
    context = :ets.lookup_element(__MODULE__, t.id, 3)
    context.handler.shutdown(context)
    Agent.stop(agent, reason)
  end

  defp id() do
    Integer.to_string(:rand.uniform(4_294_967_296), 32) <>
      Integer.to_string(:rand.uniform(4_294_967_296), 32)
  end

  defimpl Source do
    def start_link(t, context) do
      :ets.update_element(Source.Fake, t.id, {3, context})
      pid = :ets.lookup_element(Source.Fake, t.id, 2)
      send(pid, {:source_start_link, t, context})

      agent = :ets.lookup_element(Source.Fake, t.id, 4)
      send_messages_from_agent(t, agent)
      Process.link(agent)
      {:ok, agent}
    end

    def stop(t, server) do
      pid = :ets.lookup_element(Source.Fake, t.id, 2)
      send(pid, {:source_stop, t})
      context = :ets.lookup_element(__MODULE__, t.id, 3)
      context.handler.shutdown(context)
      Process.exit(server, :shutdown)
      :ok
    end

    def delete(t) do
      pid = :ets.lookup_element(Source.Fake, t.id, 2)
      send(pid, {:source_delete, t})
      :ok
    end

    defp send_messages_from_agent(source, agent) do
      case Agent.get(agent, fn s -> Map.get(s, :messages, []) end) do
        [] -> :ok
        messages -> Source.Fake.inject_messages(source, messages)
      end
    end
  end
end
