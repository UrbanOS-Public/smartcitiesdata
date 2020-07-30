defmodule SourceUdpSocket do
  @moduledoc """
  UDP message producer for pushing tests messages.
  """
  use GenServer

  def hit_me(), do: GenServer.cast(__MODULE__, :hit_me)

  def start_link(init_opts) do
    GenServer.start_link(__MODULE__, init_opts, name: __MODULE__)
  end

  def init(init_opts) do
    state = %{
      port: Keyword.fetch!(init_opts, :port),
      schedule: Keyword.get(init_opts, :schedule, false),
      interval: Keyword.get(init_opts, :interval, 100),
      messages: Keyword.get(init_opts, :messages, [])
    }

    {:ok, socket} = :gen_udp.open(state.port - 1)

    if state.schedule, do: :timer.send_interval(state.interval, :push_random)
    if length(state.messages) > 0, do: :timer.send_after(state.interval, :push_prepared)

    {:ok, Map.put(state, :socket, socket)}
  end

  def handle_cast(:hit_me, %{socket: socket, port: port} = state) do
    message = generate_payload()
    :gen_udp.send(socket, {127, 0, 0, 1}, port, message)

    {:noreply, state}
  end

  def handle_info(:push_random, %{socket: socket, port: port} = state) do
    message = generate_payload()
    :gen_udp.send(socket, {127, 0, 0, 1}, port, message)

    {:noreply, state}
  end

  def handle_info(:push_prepared, %{socket: socket, port: port} = state) do
    Enum.each(state.messages, fn message ->
      :gen_udp.send(socket, {127, 0, 0, 1}, port, message)
      Process.sleep(state.interval)
    end)

    {:noreply, state}
  end

  defp generate_payload() do
    length = :crypto.rand_uniform(0, 25)
    payload = :crypto.strong_rand_bytes(length) |> Base.url_encode64() |> binary_part(0, length)

    "{\"payload\":\"#{payload}\"}"
  end
end
