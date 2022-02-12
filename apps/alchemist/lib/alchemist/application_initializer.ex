defmodule Application.Initializer do
  @moduledoc false

  @callback do_init(keyword()) :: :ok | {:error, term()}

  defmacro __using__(_opts) do
    quote do
      use GenServer
      require Logger
      require Retry
      @behaviour Application.Initializer

      @default_max_retries 10
      @default_retry_delay 100

      def start_link(opts) do
        GenServer.start_link(__MODULE__, opts)
      end

      def init(opts) do
        state = %{
          monitor: Keyword.fetch!(opts, :monitor),
          opts: opts,
          max_retries: Keyword.get(opts, :max_retries, @default_max_retries),
          retry_delay: Keyword.get(opts, :retry_delay, @default_retry_delay)
        }

        case initialize_application(state) do
          {:ok, new_state} -> {:ok, new_state}
          {:error, reason} -> {:stop, reason}
        end
      end

      def handle_info({:DOWN, ref, _, _, _}, %{ref: ref, opts: opts} = state) do
        case initialize_application(state) do
          {:ok, new_state} -> {:noreply, new_state}
          {:error, reason} -> {:stop, reason, state}
        end
      end

      defp initialize_application(state) do
        retry_stream = Retry.DelayStreams.constant_backoff(state.retry_delay) |> Stream.take(state.max_retries)

        Retry.retry with: retry_stream, atoms: [false] do
          alive?(state.monitor)
        after
          _ ->
            with :ok <- do_init(state.opts) do
              ref = Process.monitor(state.monitor)
              {:ok, Map.put(state, :ref, ref)}
            end
        else
          _ ->
            {:error,
             "Process #{inspect(state.monitor)} was not alive after retrying for #{
               state.max_retries * state.retry_delay
             }"}
        end
      end

      defp alive?(nil), do: false
      defp alive?(pid) when is_pid(pid), do: Process.alive?(pid)
      defp alive?(name) when is_atom(name), do: alive?(Process.whereis(name))
    end
  end
end
