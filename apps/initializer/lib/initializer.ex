defmodule Initializer do
  @moduledoc """
  Behaviour for reconnecting services to pre-existing event state.
  """

  @callback on_start(state) :: {:ok, state} | {:error, term} when state: map

  defmacro __using__(opts) do
    name = Keyword.fetch!(opts, :name)
    supervisor = Keyword.fetch!(opts, :supervisor)

    quote location: :keep do
      use GenServer
      use Retry
      @behaviour Initializer

      @dialyzer [
        {:nowarn_function, handle_info: 2},
        {:no_match, init: 1}
      ]

      def start_link(init_arg) do
        GenServer.start_link(__MODULE__, init_arg, name: unquote(name))
      end

      def init(init_arg) do
        supervisor_ref = setup_monitor()

        state =
          Map.new(init_arg)
          |> Map.put(:supervisor_ref, supervisor_ref)

        case on_start(state) do
          {:ok, new_state} -> {:ok, new_state}
          {:error, reason} -> {:stop, reason}
        end
      end

      def handle_info({:DOWN, supervisor_ref, _, _, _}, %{supervisor_ref: supervisor_ref} = state) do
        retry with: constant_backoff(100) |> Stream.take(10), atoms: [false] do
          Process.whereis(unquote(supervisor)) != nil
        after
          _ ->
            supervisor_ref = setup_monitor()
            state = Map.put(state, :supervisor_ref, supervisor_ref)

            case on_start(state) do
              {:ok, new_state} -> {:noreply, state}
              {:error, reason} -> {:stop, reason, state}
            end
        else
          _ -> {:stop, "Supervisor not available", state}
        end
      end

      defp setup_monitor() do
        Process.whereis(unquote(supervisor))
        |> Process.monitor()
      end
    end
  end
end
