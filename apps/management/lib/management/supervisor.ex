defmodule Management.Supervisor do
  @moduledoc """
  Folds helper functionality around `DynamicSupervisor` usage
  into a custom `Supervisor` module.
  """

  @callback on_start_child(term, name :: term) ::
              Supervisor.child_spec() | {module, term} | module
  @callback say_my_name(term) :: atom | {:global, atom} | {:via, module, {atom, term}}

  defmacro __using__(opts) do
    name = Keyword.fetch!(opts, :name)

    quote location: :keep do
      @behaviour Management.Supervisor
      use DynamicSupervisor

      def start_link(args) do
        DynamicSupervisor.start_link(__MODULE__, args, name: unquote(name))
      end

      @impl DynamicSupervisor
      def init(_args) do
        DynamicSupervisor.init(strategy: :one_for_one)
      end

      @spec start_child(term) :: DynamicSupervisor.on_start_child()
      def start_child(input) do
        child_name = say_my_name(input)
        child_spec = on_start_child(input, child_name)
        DynamicSupervisor.start_child(unquote(name), child_spec)
      end

      @spec terminate_child(term) :: :ok | {:error, :not_found}
      def terminate_child({:via, registry, id}) do
        case apply(registry, :whereis_name, [id]) do
          :undefined -> {:error, :not_found}
          pid -> DynamicSupervisor.terminate_child(unquote(name), pid)
        end
      end

      def terminate_child(pid) when is_pid(pid) do
        DynamicSupervisor.terminate_child(unquote(name), pid)
      end

      def terminate_child(atom) when is_atom(atom) do
        case Process.whereis(atom) do
          nil -> {:error, :not_found}
          pid -> DynamicSupervisor.terminate_child(unquote(name), pid)
        end
      end

      def terminate_child(input) do
        child_name = say_my_name(input)
        terminate_child(child_name)
      end

      @spec which_children() :: [
              {:undefined, pid() | :restarting, :worker | :supervisor, [module]}
            ]
      def which_children() do
        DynamicSupervisor.which_children(unquote(name))
      end

      @spec kill_all_children() :: :ok
      def kill_all_children() do
        child_pids =
          which_children()
          |> Enum.map(fn {_, pid, _, _} -> pid end)

        refs = Enum.map(child_pids, &Process.monitor/1)

        Enum.each(child_pids, &terminate_child/1)

        Enum.each(refs, fn ref ->
          receive do
            {:DOWN, ^ref, _, _, _} -> :ok
          after
            1_000 ->
              raise "Unable to verify death of child: #{inspect(Process.info(self(), :messages))}"
          end
        end)
      end
    end
  end
end
